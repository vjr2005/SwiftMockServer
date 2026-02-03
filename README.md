# SwiftMockServer

A lightweight, embeddable HTTP mock server for Swift testing. Built with Swift 6 strict concurrency, actor-based architecture, and zero external dependencies.

![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2016%20%7C%20macOS%2013%20%7C%20tvOS%2016%20%7C%20watchOS%209-blue)
![License](https://img.shields.io/badge/License-MIT-green)

## Why SwiftMockServer?

Most HTTP mocking libraries for Swift intercept requests at the `URLProtocol` level. This works for unit tests but **breaks in XCUITest**, where the test process and the app process are separate. SwiftMockServer runs a real TCP server on the IPv6 loopback (`[::1]`), so it works everywhere — unit tests, integration tests, and UI tests.

| Feature | SwiftMockServer | [OHHTTPStubs](https://github.com/AliSoftware/OHHTTPStubs) | [Mocker](https://github.com/WeTransfer/Mocker) | [Swifter](https://github.com/httpswift/swifter) | [Embassy](https://github.com/nicklama/Embassy) |
|---------|:-:|:-:|:-:|:-:|:-:|
| Real TCP server | **Yes** | No (URLProtocol) | No (URLProtocol) | Yes | Yes |
| Works in XCUITest | **Yes** | No | No | Yes | Yes |
| Swift 6 strict concurrency | **Yes** | No | No | No | No |
| Actor-based / thread-safe | **Yes** | No | No | No | No |
| Zero dependencies | **Yes** | No | Yes | Yes | No |
| Request recording & verification | **Yes** | No | Limited | No | No |
| Result builder for batch stubs | **Yes** | No | No | No | No |
| Actively maintained for modern Swift | **Yes** | Minimal | Yes | Minimal | No |

**In short:** if you need a mock server that is concurrency-safe, works in UI tests, and has zero dependencies, SwiftMockServer is the only option in the Swift ecosystem.

## Installation

Add SwiftMockServer to your project using Swift Package Manager:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/vjr2005/SwiftMockServer.git", from: "1.0.0")
]
```

Then add it to your test target:

```swift
.testTarget(
    name: "MyAppTests",
    dependencies: ["SwiftMockServer"]
)
```

## Quick Start

```swift
import SwiftMockServer
import XCTest

final class MyAPITests: XCTestCase {
    func testFetchUsers() async throws {
        let server = try await MockServer.create()
        await server.stubJSON(.GET, "/api/users", json: """
            [{"id": 1, "name": "Alice"}, {"id": 2, "name": "Bob"}]
        """)

        let url = URL(string: await server.baseURL + "/api/users")!
        let (data, response) = try await URLSession.shared.data(from: url)

        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertTrue(await server.didReceive(method: .GET, path: "/api/users"))
        await server.stop()
    }
}
```

---

## API Reference

### MockServer (Actor)

The main HTTP mock server. Thread-safe via Swift actor isolation.

#### Creating a Server

```swift
// Manual lifecycle
let server = MockServer(port: 0, defaultResponse: .status(.notFound))
try await server.start()

// One-liner: creates, starts, and returns
let server = try await MockServer.create(port: 0)
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `port` | `UInt16` | `0` | Port to listen on. `0` = OS-assigned (recommended for parallel tests) |
| `defaultResponse` | `MockHTTPResponse` | `.status(.notFound)` | Response for unmatched routes |

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `port` | `UInt16` | The port the server is listening on (async) |
| `baseURL` | `String` | Full base URL, e.g. `"http://[::1]:54321"` (async) |
| `isRunning` | `Bool` | Whether the server is currently running |
| `requests` | `[RecordedRequest]` | All recorded incoming requests |

#### Lifecycle

```swift
try await server.start()                   // Start listening
await server.stop()                        // Stop server
let url = try await server.startAndGetURL() // Start and return baseURL
```

#### Registering Routes

**Exact path:**
```swift
@discardableResult
func register(_ method: HTTPMethod? = nil, _ path: String,
              handler: @escaping RouteHandler) -> String
```

**Parameterized path** (e.g. `/users/:id`):
```swift
@discardableResult
func registerParameterized(_ method: HTTPMethod? = nil, _ pattern: String,
                           handler: @escaping RouteHandler) -> String
```

**Prefix matching** (e.g. `/static/` matches `/static/anything`):
```swift
@discardableResult
func registerPrefix(_ method: HTTPMethod? = nil, _ prefix: String,
                    handler: @escaping RouteHandler) -> String
```

**Catch-all** (matches everything):
```swift
@discardableResult
func registerCatchAll(handler: @escaping RouteHandler) -> String
```

All registration methods return a route ID (`String`) for later removal.

When `method` is `nil`, the route matches any HTTP method.

#### Quick Stubs

For static responses without a handler closure:

```swift
// Static response
@discardableResult
func stub(_ method: HTTPMethod? = nil, _ path: String,
          response: MockHTTPResponse) -> String

// JSON string response
@discardableResult
func stubJSON(_ method: HTTPMethod? = nil, _ path: String,
              json: String, status: HTTPStatus = .ok) -> String

// Image from bundle
@discardableResult
func stubImage(_ method: HTTPMethod? = nil, _ path: String,
               named filename: String, in bundle: Bundle,
               status: HTTPStatus = .ok) throws -> String
```

#### Route Management

```swift
await server.removeRoute(id: routeID)       // Remove a specific route
await server.removeAllRoutes()              // Remove all routes
await server.setDefaultResponse(.status(.serviceUnavailable))
await server.setResponseDelay(.milliseconds(500)) // Add delay to all responses
await server.setResponseDelay(nil)                // Remove delay
```

#### Request Recording & Verification

```swift
// All requests matching a path
let reqs = await server.requests(matching: "/api/users")

// Filtered by method and path
let gets = await server.requests(method: .GET, path: "/api/users")

// Boolean check
let received = await server.didReceive(method: .POST, path: "/api/login")

// Wait for a request (useful for async operations)
let req = try await server.waitForRequest(
    method: .POST,
    path: "/api/track",
    timeout: .seconds(5),
    pollInterval: .milliseconds(100)
)

// Clear all recorded requests
await server.clearRecordedRequests()
```

#### Batch Registration

```swift
await server.registerAll(collection) // Register a RouteStubCollection
```

#### XCUITest Configuration

```swift
let config = await server.appConfig(
    baseURLEnvironmentKey: "MOCK_SERVER_URL",
    portEnvironmentKey: "MOCK_SERVER_PORT",
    useMockServerArgument: "-useMockServer"
)
```

---

### HTTPMethod

```swift
public enum HTTPMethod: String, Sendable, Hashable, CaseIterable {
    case GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS, CONNECT, TRACE
}
```

---

### HTTPStatus

A struct representing an HTTP status code with a reason phrase.

```swift
public struct HTTPStatus: Sendable, Hashable {
    public let code: Int
    public let reason: String
    public init(code: Int, reason: String)
}
```

**Predefined constants:**

| 2xx | 3xx | 4xx | 5xx |
|-----|-----|-----|-----|
| `.ok` (200) | `.movedPermanently` (301) | `.badRequest` (400) | `.internalServerError` (500) |
| `.created` (201) | `.found` (302) | `.unauthorized` (401) | `.badGateway` (502) |
| `.accepted` (202) | `.notModified` (304) | `.forbidden` (403) | `.serviceUnavailable` (503) |
| `.noContent` (204) | | `.notFound` (404) | `.gatewayTimeout` (504) |
| | | `.methodNotAllowed` (405) | |
| | | `.conflict` (409) | |
| | | `.unprocessableEntity` (422) | |
| | | `.tooManyRequests` (429) | |

Custom status codes:

```swift
let custom = HTTPStatus(code: 418, reason: "I'm a Teapot")
```

---

### MockHTTPRequest

Parsed HTTP request received by the server.

| Property | Type | Description |
|----------|------|-------------|
| `method` | `HTTPMethod` | HTTP method |
| `path` | `String` | Request path |
| `queryParameters` | `[String: String]` | Parsed query string |
| `headers` | `[String: String]` | Request headers |
| `body` | `Data?` | Raw request body |
| `bodyString` | `String?` | Body as UTF-8 string (computed) |

**Parsing JSON body:**

```swift
struct CreateUser: Codable, Sendable {
    let name: String
    let email: String
}

let user = try request.jsonBody(CreateUser.self)
```

---

### MockHTTPResponse

HTTP response to send back to the client.

| Property | Type | Default |
|----------|------|---------|
| `status` | `HTTPStatus` | `.ok` |
| `headers` | `[String: String]` | `[:]` |
| `body` | `Data?` | `nil` |

**Static builders:**

```swift
// JSON from Encodable
let response = try MockHTTPResponse.json(myModel)
let response = try MockHTTPResponse.json(myModel, status: .created)

// JSON from raw string
let response = MockHTTPResponse.json(#"{"key": "value"}"#)

// Plain text
let response = MockHTTPResponse.text("Hello, world!")

// HTML
let response = MockHTTPResponse.html("<h1>Title</h1>")

// Status only (no body)
let response = MockHTTPResponse.status(.noContent)

// Raw data with content type
let response = MockHTTPResponse.data(pdfData, contentType: "application/pdf")

// JSON file from bundle
let response = MockHTTPResponse.jsonFile(named: "users.json", in: .module)

// Image with auto-detected content type (from magic bytes, falls back to PNG)
let response = MockHTTPResponse.image(imageData)

// Image with explicit content type
let response = MockHTTPResponse.image(imageData, contentType: .jpeg)

// Image file from bundle (supports png, jpg, gif, webp, svg, heic, tiff, bmp, ico)
let response = MockHTTPResponse.imageFile(named: "avatar.png", in: .module)
```

---

### ImageContentType

Image MIME content types for use with `.image(_:contentType:status:)` and `.imageFile(named:in:status:)`.

```swift
public enum ImageContentType: String, Sendable {
    case png  = "image/png"
    case jpeg = "image/jpeg"
    case gif  = "image/gif"
    case webp = "image/webp"
    case svg  = "image/svg+xml"
    case heic = "image/heic"
    case tiff = "image/tiff"
    case bmp  = "image/bmp"
    case ico  = "image/x-icon"
}
```

**Initializers:**

| Initializer | Description |
|-------------|-------------|
| `init?(fileExtension:)` | From a file extension (e.g. `"png"`, `"jpg"`, `"tif"`). Returns `nil` for unrecognized extensions. |
| `init?(detecting:)` | From raw `Data` by inspecting magic bytes. Returns `nil` for unrecognized or empty data. |

**Magic byte detection** supports: PNG, JPEG, GIF, WebP, BMP, TIFF (little-endian and big-endian), ICO, and HEIC (heic/heix/mif1 brands). SVG is excluded because it is text-based and unreliable to detect from raw bytes.

```swift
let type = ImageContentType(fileExtension: "jpg")   // .jpeg
let type = ImageContentType(detecting: pngData)      // .png (from magic bytes)
```

---

### RecordedRequest

A recorded incoming request with metadata.

| Property | Type | Description |
|----------|------|-------------|
| `request` | `MockHTTPRequest` | The parsed request |
| `timestamp` | `Date` | When the request was received |
| `matchedRoute` | `String?` | ID of the matched route (if any) |

---

### MockServerError

```swift
public enum MockServerError: Error, Sendable {
    case bindFailed(String)
    case listenFailed(String)
    case alreadyRunning
    case notRunning
    case noBody
    case invalidRequest(String)
    case portUnavailable(UInt16)
    case timeout
}
```

---

### Routing Types

**`RouteHandler`** — the handler signature for all routes:

```swift
public typealias RouteHandler = @Sendable (MockHTTPRequest) async throws -> MockHTTPResponse
```

**`RoutePattern`** — how a route matches incoming paths:

```swift
public enum RoutePattern: Sendable {
    case exact(String)         // Exact path match
    case parameterized(String) // Path with :param placeholders
    case prefix(String)        // Prefix match
    case any                   // Matches everything
}
```

**`Route`** — a registered route:

```swift
public struct Route: Sendable {
    public let id: String
    public let method: HTTPMethod?
    public let pattern: RoutePattern
    public let handler: RouteHandler
}
```

**`RouteMatch`** — result of matching a request:

```swift
public struct RouteMatch: Sendable {
    public let route: Route
    public let pathParameters: [String: String]
}
```

**`RouterEngine`** — stateless route matcher:

```swift
public enum RouterEngine: Sendable {
    public static func match(request: MockHTTPRequest, routes: [Route]) -> RouteMatch?
}
```

---

### RouteStubCollection

Batch route registration using a result builder.

```swift
let stubs = RouteStubCollection {
    RouteStubCollection.Stub(method: .GET, path: "/api/users", response: .json("[]"))
    RouteStubCollection.Stub(method: .GET, path: "/api/config", response: .json(#"{"v":1}"#))
    RouteStubCollection.Stub(method: .POST, path: "/api/users", response: .status(.created))
}
await server.registerAll(stubs)
```

The `@RouteStubBuilder` result builder supports `if/else`, `for-in` loops, and optional chaining.

---

### MockServerAppConfig

Configuration for passing mock server info to an app launched in XCUITest.

| Property | Type | Description |
|----------|------|-------------|
| `baseURL` | `String` | Server base URL |
| `port` | `UInt16` | Server port |
| `launchArguments` | `[String]` | Arguments to pass to `XCUIApplication` |
| `launchEnvironment` | `[String: String]` | Environment to pass to `XCUIApplication` |

---

### MockServerDetector

Use in your **app target** (not test target) to detect when running with a mock server.

```swift
MockServerDetector.isUsingMockServer  // Bool
MockServerDetector.baseURL            // String?
MockServerDetector.port               // UInt16?
```

---

### HTTPParser

Stateless HTTP/1.1 parser and serializer.

```swift
public enum HTTPParser: Sendable {
    public static func parse(_ data: Data) throws -> MockHTTPRequest
    public static func serialize(_ response: MockHTTPResponse) -> Data
}
```

---

## How-To Guides

### 1. Create a Server and Register a JSON Route

```swift
let server = try await MockServer.create()

await server.register(.GET, "/api/users") { _ in
    .json(#"[{"id": 1, "name": "Alice"}]"#)
}

let url = URL(string: await server.baseURL + "/api/users")!
let (data, _) = try await URLSession.shared.data(from: url)
// data contains the JSON array

await server.stop()
```

### 2. Stub JSON with One Line

```swift
let server = try await MockServer.create()
await server.stubJSON(.GET, "/api/status", json: #"{"status": "healthy"}"#)
```

No handler closure needed. The JSON is returned as-is with `Content-Type: application/json`.

### 3. Serve a JSON File from a Fixture

Place `users.json` in your test target's resources, then:

```swift
await server.stub(.GET, "/api/users",
    response: .jsonFile(named: "users.json", in: .module)!)
```

### 4. Serve an Image

**From raw data (auto-detects format):**

```swift
let pngData = try Data(contentsOf: pngURL)
await server.stub(.GET, "/avatar.png", response: .image(pngData))
// Content-Type is auto-detected from magic bytes (PNG in this case)
```

**From raw data with explicit type:**

```swift
await server.stub(.GET, "/photo.jpg",
    response: .image(jpegData, contentType: .jpeg))
```

**From a fixture file in a bundle:**

```swift
try await server.stubImage(.GET, "/avatar.png",
    named: "avatar.png", in: .module)
```

Or manually:

```swift
await server.stub(.GET, "/avatar.png",
    response: .imageFile(named: "avatar.png", in: .module)!)
```

Supported image formats: `png`, `jpg`, `gif`, `webp`, `svg`, `heic`, `tiff`, `bmp`, `ico`.

Auto-detection from magic bytes works for all formats except SVG (which is text-based). When detection fails, `.png` is used as fallback.

### 5. Parameterized Routes (`/users/:id`)

```swift
await server.registerParameterized(.GET, "/users/:id") { request in
    // Path parameters are captured during routing.
    // Use the path to extract the value:
    let components = request.path.split(separator: "/")
    let userId = components.last ?? "unknown"
    return .json(#"{"id": "\#(userId)"}"#)
}
```

### 6. Prefix Routes (Static File Server)

```swift
await server.registerPrefix(.GET, "/static/") { request in
    .text("Serving: \(request.path)")
}
// Matches /static/css/app.css, /static/js/main.js, etc.
```

### 7. Catch-All for Unregistered Routes

```swift
await server.registerCatchAll { request in
    .json(#"{"error": "Not mocked", "path": "\#(request.path)"}"#, status: .notFound)
}
```

The catch-all matches any method and path not handled by other routes.

### 8. Override a Route Mid-Test

Routes are matched LIFO (last registered wins). Register a new route for the same path to override:

```swift
// Initial state
await server.stubJSON(.GET, "/api/feature", json: #"{"enabled": false}"#)

// ... run some test steps ...

// Override for the next phase of the test
await server.stubJSON(.GET, "/api/feature", json: #"{"enabled": true}"#)
```

Or remove the old one explicitly:

```swift
let routeID = await server.stubJSON(.GET, "/api/feature", json: #"{"enabled": false}"#)
// ... later ...
await server.removeRoute(id: routeID)
await server.stubJSON(.GET, "/api/feature", json: #"{"enabled": true}"#)
```

### 9. Verify a Request Was Received

```swift
await server.stubJSON(.GET, "/api/track", json: #"{"ok": true}"#)

// ... trigger the request from your code under test ...

XCTAssertTrue(await server.didReceive(method: .GET, path: "/api/track"))

let recorded = await server.requests(method: .GET, path: "/api/track")
XCTAssertEqual(recorded.count, 1)
```

### 10. Wait for a Request (`waitForRequest`)

Useful when the request is triggered asynchronously and you need to wait for it:

```swift
await server.stub(.POST, "/api/analytics", response: .status(.ok))

// Trigger the async operation that will eventually POST to /api/analytics
triggerAnalyticsFlush()

let recorded = try await server.waitForRequest(
    method: .POST,
    path: "/api/analytics",
    timeout: .seconds(5)
)
XCTAssertNotNil(recorded.request.body)
```

Throws `MockServerError.timeout` if the request doesn't arrive in time.

### 11. Register Routes in Batch with Result Builder

```swift
let isLoggedIn = true

let collection = RouteStubCollection {
    RouteStubCollection.Stub(
        method: .GET, path: "/api/config",
        response: .json(#"{"version": 1}"#)
    )
    RouteStubCollection.Stub(
        method: .GET, path: "/api/users",
        response: .json("[]")
    )
    if isLoggedIn {
        RouteStubCollection.Stub(
            method: .GET, path: "/api/profile",
            response: .json(#"{"name": "Alice"}"#)
        )
    }
}

await server.registerAll(collection)
```

### 12. Simulate Server Errors

```swift
await server.stub(.POST, "/api/payment", response: .status(.internalServerError))
await server.stub(.GET, "/api/admin", response: .status(.unauthorized))
await server.stub(.GET, "/api/limited", response: .status(.tooManyRequests))
```

### 13. Add Delay to Responses

Simulate slow network conditions:

```swift
await server.setResponseDelay(.milliseconds(500))

// All responses will now be delayed by 500ms

await server.setResponseDelay(nil) // Remove delay
```

### 14. Use MockServer in XCUITest (UI Testing)

```swift
import XCTest
import SwiftMockServer

final class LoginUITests: XCTestCase {
    var server: MockServer!

    override func setUp() async throws {
        server = try await MockServer.create()
        await server.stubJSON(.POST, "/api/login", json: #"{"token": "abc123"}"#)
        await server.stubJSON(.GET, "/api/profile", json: #"{"name": "Alice"}"#)
    }

    override func tearDown() async throws {
        await server.stop()
    }

    func testLoginFlow() async throws {
        let config = await server.appConfig()

        let app = XCUIApplication()
        app.launchArguments += config.launchArguments
        app.launchEnvironment.merge(config.launchEnvironment) { _, new in new }
        app.launch()

        // Interact with the app...

        XCTAssertTrue(await server.didReceive(method: .POST, path: "/api/login"))
    }
}
```

### 15. Detect the Mock Server in Your App (`MockServerDetector`)

In your **app target** (not the test target), conditionally point your networking layer at the mock server:

```swift
import SwiftMockServer

@main
struct MyApp: App {
    init() {
        #if DEBUG
        if MockServerDetector.isUsingMockServer,
           let baseURL = MockServerDetector.baseURL {
            APIClient.shared.baseURL = URL(string: baseURL)!
        }
        #endif
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

`MockServerDetector` reads from `ProcessInfo.processInfo.arguments` and `.environment` using the same keys that `appConfig()` sets.

### 16. Read the JSON Body of an Incoming Request

```swift
struct CreateUser: Codable, Sendable {
    let name: String
    let email: String
}

await server.register(.POST, "/api/users") { request in
    let user = try request.jsonBody(CreateUser.self)
    return try .json(["id": UUID().uuidString, "name": user.name], status: .created)
}
```

Or read the raw body string:

```swift
await server.register(.POST, "/api/webhook") { request in
    if let body = request.bodyString {
        print("Received: \(body)")
    }
    return .status(.ok)
}
```

### 17. Dynamic Responses Based on the Request

```swift
await server.register(.GET, "/api/search") { request in
    let query = request.queryParameters["q"] ?? ""
    if query.isEmpty {
        return .json(#"{"results": []}"#)
    }
    return .json(#"{"results": [{"title": "Result for \#(query)"}]}"#)
}
```

### 18. Multiple Servers in Parallel

Use port `0` (the default) so each server gets a unique OS-assigned port:

```swift
let authServer = try await MockServer.create()
let dataServer = try await MockServer.create()

await authServer.stubJSON(.POST, "/login", json: #"{"token": "x"}"#)
await dataServer.stubJSON(.GET, "/items", json: "[]")

let authURL = await authServer.baseURL  // e.g. http://[::1]:54321
let dataURL = await dataServer.baseURL  // e.g. http://[::1]:54322

// Point different services at different servers

await authServer.stop()
await dataServer.stop()
```

---

## XCUITest Integration (Step by Step)

Complete workflow for using SwiftMockServer in UI tests:

**Step 1.** Add the SPM dependency to **both** your app target and your UI test target.

**Step 2.** Create and configure the server in your test's `setUp`:

```swift
override func setUp() async throws {
    server = try await MockServer.create()
    await server.stubJSON(.GET, "/api/users", json: """
        [{"id": 1, "name": "Alice"}]
    """)
}
```

**Step 3.** Get the app configuration and launch:

```swift
func testUserList() async throws {
    let config = await server.appConfig()

    let app = XCUIApplication()
    app.launchArguments += config.launchArguments
    app.launchEnvironment.merge(config.launchEnvironment) { _, new in new }
    app.launch()

    // UI assertions...
}
```

**Step 4.** In your **app target**, detect and redirect to the mock server:

```swift
#if DEBUG
if MockServerDetector.isUsingMockServer,
   let url = MockServerDetector.baseURL {
    NetworkConfig.baseURL = url
}
#endif
```

**Step 5.** Verify and clean up:

```swift
override func tearDown() async throws {
    // Verify expected requests were made
    XCTAssertTrue(await server.didReceive(method: .GET, path: "/api/users"))
    await server.stop()
}
```

---

## Architecture

### Request Flow

```
Client Request
    |
    v
SocketListener (actor) ── accepts TCP connections
    |
    v
HTTPParser.parse(_:) ── parses raw bytes into MockHTTPRequest
    |
    v
RouterEngine.match(request:routes:) ── LIFO matching against registered routes
    |                                     |
    | (match found)                       | (no match)
    v                                     v
RouteHandler ── async handler            Default Response
    |
    v
MockHTTPResponse
    |
    v
HTTPParser.serialize(_:) ── serializes to raw HTTP/1.1 bytes
    |
    v
Response sent to client
    |
    v
RecordedRequest ── stored for later verification
```

### Concurrency Model

- **`MockServer`** is an `actor`, ensuring all state mutation is serialized.
- **`SocketListener`** is an `actor` managing the TCP socket lifecycle.
- All model types (`MockHTTPRequest`, `MockHTTPResponse`, `RecordedRequest`, etc.) are value types conforming to `Sendable`.
- `RouteHandler` is `@Sendable`, safe to call from any context.
- The entire library compiles under Swift 6 strict concurrency checking with no warnings.

### Route Matching Order

Routes are matched **LIFO** (last-in, first-out). The most recently registered route that matches the incoming request wins. This makes it easy to override behavior mid-test by registering a new route for the same path.

Priority among route types for the same registration order:
1. **Exact** match
2. **Parameterized** match
3. **Prefix** match
4. **Catch-all**

---

## License

MIT
