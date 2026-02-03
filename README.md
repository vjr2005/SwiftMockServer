# SwiftMockServer

**A lightweight HTTP mock server for iOS UI testing, built from scratch for Swift 6 with strict concurrency and parallel testing support.**

[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20|%20macOS%20|%20tvOS%20|%20watchOS-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Why SwiftMockServer?

| Feature | Swifter | Embassy | Peasy | **SwiftMockServer** |
|---|---|---|---|---|
| Swift 6 Strict Concurrency | ❌ | ❌ | ❌ | ✅ |
| `Sendable` compliant | ❌ | ❌ | ❌ | ✅ |
| `actor`-based (thread-safe) | ❌ | ❌ | ❌ | ✅ |
| `async/await` API | ❌ | ❌ | ❌ | ✅ |
| Parallel testing (multi-simulator) | ⚠️ Manual | ⚠️ Manual | ⚠️ Manual | ✅ Automatic |
| Auto-assigned port | ❌ | ❌ | ✅ | ✅ |
| Request recording | ❌ | ❌ | ❌ | ✅ |
| Zero dependencies | ✅ | ✅ | ✅ | ✅ |
| Actively maintained | ❌ | ❌ | ❌ | ✅ |

## Installation

### Swift Package Manager

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/youruser/SwiftMockServer.git", from: "1.0.0")
]

// In your UI test target:
.testTarget(
    name: "MyAppUITests",
    dependencies: ["SwiftMockServer"]
)
```

### Local Development (mise + Tuist)

This project uses [mise](https://mise.jdx.dev) to manage development tools and [Tuist](https://tuist.dev) to generate the Xcode project.

```bash
# 1. Install mise (if you don't have it)
curl https://mise.jdx.dev/install.sh | sh
echo 'eval "$(~/.local/bin/mise activate zsh)"' >> ~/.zshrc  # or bash
source ~/.zshrc

# 2. Full bootstrap (installs tuist + generates project)
make bootstrap
# — or manually: —
mise install          # installs tuist 4.x
mise run setup        # tuist install + tuist generate

# 3. Open in Xcode
open *.xcworkspace
```

**Common commands:**

| Command | Description |
|---|---|
| `mise run generate` | Regenerate the `.xcworkspace` |
| `mise run build` | Build the framework |
| `mise run test` | Run the tests |
| `mise run edit` | Edit Tuist manifests in Xcode |
| `mise run graph` | Visualize the dependency graph |
| `mise run clean` | Clean generated artifacts |

## Quick Start

### 1. In Your UI Tests

```swift
import XCTest
import SwiftMockServer

final class LoginUITests: XCTestCase {
    
    let server = MockServer() // Auto-assigned port
    
    override func setUp() async throws {
        try await server.start()
        
        // Register mock responses
        await server.stubJSON(.POST, "/api/auth/login", json: """
        {
            "token": "fake-jwt-token",
            "user": {"id": 1, "name": "Test User"}
        }
        """)
        
        await server.stubJSON(.GET, "/api/profile", json: """
        {"id": 1, "name": "Test User", "email": "test@example.com"}
        """)
    }
    
    override func tearDown() async throws {
        await server.stop()
    }
    
    func testSuccessfulLogin() async throws {
        let config = await server.appConfig()
        
        let app = XCUIApplication()
        app.launchArguments += config.launchArguments
        app.launchEnvironment.merge(config.launchEnvironment) { _, new in new }
        app.launch()
        
        // Interact with the UI...
        app.textFields["email"].tap()
        app.textFields["email"].typeText("test@example.com")
        app.secureTextFields["password"].tap()
        app.secureTextFields["password"].typeText("password123")
        app.buttons["Login"].tap()
        
        // Verify the profile screen is displayed
        XCTAssertTrue(app.staticTexts["Test User"].waitForExistence(timeout: 5))
        
        // Verify the login request was made
        let loginRequests = await server.requests(method: .POST, path: "/api/auth/login")
        XCTAssertEqual(loginRequests.count, 1)
    }
}
```

### 2. In Your App (main target code)

```swift
// AppDelegate.swift or wherever you configure networking
#if DEBUG
import SwiftMockServer

if MockServerDetector.isUsingMockServer {
    let baseURL = MockServerDetector.baseURL ?? "http://localhost:8080"
    NetworkClient.shared.baseURL = URL(string: baseURL)!
}
#endif
```

## Parallel Testing with Multiple Simulators

`SwiftMockServer` is designed to solve the main problem of parallel testing: **each server instance automatically gets a unique port**.

```swift
// Each test runner process gets its own server
// with a different port — no collisions, no extra configuration.

final class ParallelSafeTests: XCTestCase {
    let server = MockServer() // Port 0 = auto-assigned by the OS
    
    override func setUp() async throws {
        try await server.start()
        // The OS assigns a free port automatically
        // Simulator 1 → port 49152
        // Simulator 2 → port 49153  
        // Simulator 3 → port 49154
        // etc.
    }
}
```

### Why Does It Work?

1. **`actor` isolation**: All mutable server state is protected by actor isolation, eliminating data races between concurrent tests.
2. **Port 0**: The OS assigns a free ephemeral port. Each test runner process is independent.
3. **`Sendable` compliant**: All routes, responses, and configurations can be passed across concurrency contexts without issues.

### Xcode Configuration

```
Product → Scheme → Edit Scheme → Test → Options → 
  ✅ Execute in parallel
  ✅ Parallelize using: Simulators (or "classes")
```

## Full API

### Registering Routes

```swift
// Quick static response
await server.stubJSON(.GET, "/api/users", json: "[{\"id\": 1}]")
await server.stub(.DELETE, "/api/users/1", response: .status(.noContent))

// Dynamic handler with request access
await server.register(.POST, "/api/users") { request in
    let body = try request.jsonBody(CreateUserRequest.self)
    return try .json(CreateUserResponse(id: UUID(), name: body.name))
}

// Parameterized routes
await server.registerParameterized(.GET, "/api/users/:id") { request in
    .json("{\"id\": 42, \"name\": \"Alice\"}")
}

// Prefix matching
await server.registerPrefix(.GET, "/api/v2/") { _ in
    .json("{\"version\": 2}")
}

// Catch-all
await server.registerCatchAll { request in
    .text("Caught: \(request.method) \(request.path)", status: .ok)
}
```

### Responses

```swift
// JSON from string
MockHTTPResponse.json("{\"ok\": true}")

// JSON from Encodable
try MockHTTPResponse.json(myEncodableObject)

// Plain text
MockHTTPResponse.text("Hello, World!")

// HTML
MockHTTPResponse.html("<h1>Test</h1>")

// Status code only
MockHTTPResponse.status(.unauthorized)

// Binary data
MockHTTPResponse.data(imageData, contentType: "image/png")

// From a JSON file in the test bundle
MockHTTPResponse.jsonFile(named: "users_response", in: Bundle(for: Self.self))
```

### Request Recording and Verification

```swift
// Verify a request was received
let didLogin = await server.didReceive(method: .POST, path: "/api/login")

// Get all requests to a path
let requests = await server.requests(matching: "/api/analytics")

// Wait for a request to arrive (with timeout)
let loginRequest = try await server.waitForRequest(
    method: .POST,
    path: "/api/login",
    timeout: .seconds(5)
)

// Inspect the request body
let body = try loginRequest.request.jsonBody(LoginRequest.self)
XCTAssertEqual(body.email, "test@example.com")

// Clear recorded requests
await server.clearRecordedRequests()
```

### Batch Registration

```swift
let commonStubs = RouteStubCollection([
    .init(method: .GET, path: "/api/config", response: .json("{\"feature_flags\": {}}")),
    .init(method: .GET, path: "/api/health", response: .text("ok")),
    .init(method: .GET, path: "/api/user/me", response: .json("{\"id\": 1, \"name\": \"Test\"}")),
])

// Apply to any server
await server.registerAll(commonStubs)
```

### Mid-Test Route Overrides

```swift
func testErrorRecovery() async throws {
    // Start with an error
    await server.stubJSON(.GET, "/api/data", 
        json: "{\"error\": \"server_error\"}", 
        status: .internalServerError)
    
    // ... interact with the UI, verify error message...
    
    // Now "fix" the server (LIFO: last registered route takes priority)
    await server.stubJSON(.GET, "/api/data",
        json: "{\"items\": []}", 
        status: .ok)
    
    // ... pull to refresh, verify it works now...
}
```

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                  MockServer (actor)                   │
│                                                      │
│  ┌──────────┐  ┌──────────┐  ┌────────────────────┐ │
│  │  Routes   │  │ Recorded │  │  Default Response  │ │
│  │  [Route]  │  │ Requests │  │                    │ │
│  └──────────┘  └──────────┘  └────────────────────┘ │
│       ▲                                              │
│       │ match                                        │
│  ┌──────────────┐                                    │
│  │ RouterEngine  │ (pure functions, Sendable)        │
│  └──────────────┘                                    │
│       ▲                                              │
│       │ parse                                        │
│  ┌──────────────┐                                    │
│  │  HTTPParser   │ (pure functions, Sendable)        │
│  └──────────────┘                                    │
│       ▲                                              │
│       │ raw data                                     │
│  ┌──────────────────┐                                │
│  │ SocketListener    │ (actor)                       │
│  │ POSIX sockets     │                               │
│  │ accept() loop in  │                               │
│  │ detached Task     │                               │
│  └──────────────────┘                                │
└──────────────────────────────────────────────────────┘
```

### Key Design Decisions

1. **`MockServer` is an `actor`**: All state mutation (routes, recorded requests) is protected by actor isolation. No manual locks or `DispatchQueue`.

2. **All types are `Sendable`**: `MockHTTPRequest`, `MockHTTPResponse`, `Route`, `HTTPStatus`, etc. are value structs/enums, automatically Sendable.

3. **`RouteHandler` is `@Sendable`**: Route handler closures can be created in any concurrency context and passed to the actor without issues.

4. **POSIX sockets**: No SwiftNIO or heavy framework dependencies. Standard POSIX sockets that work on iOS, macOS, and simulators.

5. **Port 0**: The default behavior uses port 0, letting the OS assign a free ephemeral port. This is what makes parallel testing possible without configuration.

## Compatibility

- **Swift**: 6.0+
- **Xcode**: 16.0+  
- **iOS**: 16.0+
- **macOS**: 13.0+
- **tvOS**: 16.0+
- **watchOS**: 9.0+

## License

MIT License. See [LICENSE](LICENSE) for details.
