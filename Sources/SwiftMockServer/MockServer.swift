// MockServer.swift
// SwiftMockServer
//
// The main mock HTTP server. Implemented as an `actor` for inherent
// Sendable compliance and thread-safe mutable state.
// Designed for parallel UI testing with multiple simultaneous simulators.

import Foundation

// MARK: - MockServer

/// A lightweight, embeddable HTTP mock server for Swift testing.
///
/// `MockServer` is an `actor`, which means:
/// - It's automatically `Sendable` (Swift 6 strict concurrency safe)
/// - All mutable state is protected by actor isolation
/// - It can be safely shared across concurrent test tasks
///
/// ## Quick Start
///
/// ```swift
/// // One-liner: create and start
/// let server = try await MockServer.create()
///
/// // Register a JSON stub
/// await server.stubJSON(.GET, "/api/users", json: """
///     [{"id": 1, "name": "Alice"}]
/// """)
///
/// // Use the server
/// let url = URL(string: await server.baseURL + "/api/users")!
/// let (data, _) = try await URLSession.shared.data(from: url)
///
/// // Verify and stop
/// XCTAssertTrue(await server.didReceive(method: .GET, path: "/api/users"))
/// await server.stop()
/// ```
///
/// ## XCUITest
///
/// ```swift
/// let server = try await MockServer.create()
/// await server.stubJSON(.GET, "/api/users", json: "[]")
///
/// let config = await server.appConfig()
/// let app = XCUIApplication()
/// app.launchArguments += config.launchArguments
/// app.launchEnvironment.merge(config.launchEnvironment) { _, new in new }
/// app.launch()
/// ```
public actor MockServer {

    // MARK: - State

    private var routes: [Route] = []
    private var recordedRequests: [RecordedRequest] = []
    private var listener: SocketListener?
    private var _isRunning = false
    private var defaultResponse: MockHTTPResponse
    private let requestedPort: UInt16
    private var responseDelay: Duration?

    /// Whether the server is currently listening for connections.
    ///
    /// Becomes `true` after ``start()`` and `false` after ``stop()``.
    public var isRunning: Bool { _isRunning }

    /// The port the server is listening on.
    ///
    /// When initialized with port `0` (the default), this returns the OS-assigned port
    /// after ``start()`` is called. Before starting, returns the requested port.
    ///
    /// ```swift
    /// let server = try await MockServer.create() // port 0 = auto-assigned
    /// let port = await server.port // e.g., 54321
    /// ```
    public var port: UInt16 {
        get async {
            if let listener {
                return await listener.port
            }
            return requestedPort
        }
    }

    /// The base URL for this server (e.g., `"http://localhost:54321"`).
    ///
    /// Use this to construct full URLs for requests:
    ///
    /// ```swift
    /// let url = URL(string: await server.baseURL + "/api/users")!
    /// ```
    public var baseURL: String {
        get async {
            let p = await port
            return "http://localhost:\(p)"
        }
    }

    /// All recorded requests in order of receipt.
    ///
    /// Every request received by the server is recorded here, regardless of whether
    /// a matching route was found. Use the filtering methods (``requests(matching:)``,
    /// ``requests(method:path:)``, ``didReceive(method:path:)``) for targeted checks.
    ///
    /// ```swift
    /// let allRequests = await server.requests
    /// XCTAssertEqual(allRequests.count, 3)
    /// ```
    public var requests: [RecordedRequest] { recordedRequests }

    // MARK: - Init

    /// Create a new mock server.
    ///
    /// The server is not started automatically — call ``start()`` or use the
    /// convenience factory ``create(port:defaultResponse:)`` instead.
    ///
    /// ```swift
    /// let server = MockServer()           // Auto-assigned port, 404 default
    /// let server = MockServer(port: 8080) // Fixed port
    /// ```
    ///
    /// - Parameters:
    ///   - port: Port to listen on. Use `0` (default) for OS-assigned port.
    ///           Automatic assignment is recommended for parallel testing.
    ///   - defaultResponse: Response for unmatched routes. Defaults to `404 Not Found`.
    public init(
        port: UInt16 = 0,
        defaultResponse: MockHTTPResponse = .status(.notFound)
    ) {
        self.requestedPort = port
        self.defaultResponse = defaultResponse
    }

    // MARK: - Lifecycle

    /// Start listening for HTTP connections.
    ///
    /// Binds to the configured port and begins accepting TCP connections.
    /// When using port `0` (default), the OS assigns an available port automatically —
    /// query ``port`` or ``baseURL`` after starting to discover it.
    ///
    /// ```swift
    /// let server = MockServer()
    /// try await server.start()
    /// print(await server.baseURL) // "http://localhost:54321"
    /// ```
    ///
    /// - Throws: ``MockServerError/alreadyRunning`` if the server is already started.
    ///   ``MockServerError/bindFailed(_:)`` if the port is unavailable.
    public func start() async throws {
        guard !_isRunning else {
            throw MockServerError.alreadyRunning
        }

        let newListener = try SocketListener(port: requestedPort)
        self.listener = newListener

        // The handler receives a parsed request and returns a response.
        // I/O is handled by ConnectionDispatcher using DispatchSource (non-blocking).
        // This closure only runs on the actor for route matching and handler invocation.
        let handler: ConnectionHandler = { [weak self] request in
            guard let self else {
                return .status(.internalServerError)
            }
            return await self.resolveResponse(for: request)
        }

        try await newListener.start(handler: handler)
        _isRunning = true
    }

    /// Stop the server and release the port.
    ///
    /// Safe to call even if the server is not running. After stopping, the server
    /// can be started again with ``start()``.
    ///
    /// ```swift
    /// await server.stop()
    /// ```
    public func stop() async {
        if let listener {
            await listener.stop()
        }
        listener = nil
        _isRunning = false
    }

    // MARK: - Route Registration

    /// Register a route with an exact path and a dynamic handler.
    ///
    /// The handler receives the parsed ``MockHTTPRequest`` and returns a ``MockHTTPResponse``.
    /// Routes are matched LIFO (last registered = highest priority), so you can override
    /// a route mid-test by registering a new one for the same path.
    ///
    /// ```swift
    /// await server.register(.GET, "/api/users") { request in
    ///     let page = request.queryParameters["page"] ?? "1"
    ///     return .json(#"{"page": \#(page)}"#)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - method: HTTP method to match, or `nil` to match any method.
    ///   - path: Exact path to match (e.g., `"/api/users"`).
    ///   - handler: Async closure that returns a response.
    /// - Returns: The route's unique ID, usable with ``removeRoute(id:)``.
    @discardableResult
    public func register(
        _ method: HTTPMethod? = nil,
        _ path: String,
        handler: @escaping RouteHandler
    ) -> String {
        let route = Route(
            method: method,
            pattern: .exact(path),
            handler: handler
        )
        routes.insert(route, at: 0) // LIFO order
        return route.id
    }

    /// Register a parameterized route with `:param` placeholders.
    ///
    /// Path segments prefixed with `:` are treated as named parameters.
    /// Captured values are available in ``RouteMatch/pathParameters``.
    ///
    /// ```swift
    /// await server.registerParameterized(.GET, "/users/:id") { request in
    ///     let id = request.path.split(separator: "/").last.map(String.init) ?? ""
    ///     return .json(#"{"id": "\#(id)"}"#)
    /// }
    /// // Matches: /users/42, /users/abc, etc.
    /// ```
    ///
    /// - Parameters:
    ///   - method: HTTP method to match, or `nil` for any method.
    ///   - pattern: Path template with `:param` segments (e.g., `"/users/:id"`).
    ///   - handler: Async closure that returns a response.
    /// - Returns: The route's unique ID, usable with ``removeRoute(id:)``.
    @discardableResult
    public func registerParameterized(
        _ method: HTTPMethod? = nil,
        _ pattern: String,
        handler: @escaping RouteHandler
    ) -> String {
        let route = Route(
            method: method,
            pattern: .parameterized(pattern),
            handler: handler
        )
        routes.insert(route, at: 0)
        return route.id
    }

    /// Register a prefix route that matches any path starting with the given prefix.
    ///
    /// ```swift
    /// await server.registerPrefix(.GET, "/static/") { request in
    ///     .text("Serving: \(request.path)")
    /// }
    /// // Matches: /static/css/app.css, /static/js/main.js, etc.
    /// ```
    ///
    /// - Parameters:
    ///   - method: HTTP method to match, or `nil` for any method.
    ///   - prefix: The path prefix to match (e.g., `"/static/"`).
    ///   - handler: Async closure that returns a response.
    /// - Returns: The route's unique ID, usable with ``removeRoute(id:)``.
    @discardableResult
    public func registerPrefix(
        _ method: HTTPMethod? = nil,
        _ prefix: String,
        handler: @escaping RouteHandler
    ) -> String {
        let route = Route(
            method: method,
            pattern: .prefix(prefix),
            handler: handler
        )
        routes.insert(route, at: 0)
        return route.id
    }

    /// Register a catch-all route that matches any method and path.
    ///
    /// Useful for logging or returning a custom default response for unmatched routes.
    ///
    /// ```swift
    /// await server.registerCatchAll { request in
    ///     .json(#"{"error": "Not mocked: \#(request.path)"}"#, status: .notFound)
    /// }
    /// ```
    ///
    /// - Parameter handler: Async closure that returns a response.
    /// - Returns: The route's unique ID, usable with ``removeRoute(id:)``.
    @discardableResult
    public func registerCatchAll(
        handler: @escaping RouteHandler
    ) -> String {
        let route = Route(
            pattern: .any,
            handler: handler
        )
        routes.insert(route, at: 0)
        return route.id
    }

    // MARK: - Quick Registration (static responses)

    /// Register a static response for an exact path (no handler closure needed).
    ///
    /// This is a convenience wrapper around ``register(_:_:handler:)`` that always
    /// returns the same response.
    ///
    /// ```swift
    /// await server.stub(.GET, "/api/config",
    ///     response: .json(#"{"version": 1}"#))
    /// ```
    ///
    /// - Parameters:
    ///   - method: HTTP method to match, or `nil` for any method.
    ///   - path: Exact path to match.
    ///   - response: The static response to return for every match.
    /// - Returns: The route's unique ID, usable with ``removeRoute(id:)``.
    @discardableResult
    public func stub(
        _ method: HTTPMethod? = nil,
        _ path: String,
        response: MockHTTPResponse
    ) -> String {
        let capturedResponse = response
        return register(method, path) { _ in capturedResponse }
    }

    /// Register a static JSON string response for an exact path.
    ///
    /// The JSON string is returned as-is with `Content-Type: application/json`.
    ///
    /// ```swift
    /// await server.stubJSON(.GET, "/api/users", json: """
    ///     [{"id": 1, "name": "Alice"}]
    /// """)
    ///
    /// // With a custom status
    /// await server.stubJSON(.POST, "/api/users",
    ///     json: #"{"id": 2}"#, status: .created)
    /// ```
    ///
    /// - Parameters:
    ///   - method: HTTP method to match, or `nil` for any method.
    ///   - path: Exact path to match.
    ///   - json: Raw JSON string to return as the response body.
    ///   - status: HTTP status code. Defaults to `.ok`.
    /// - Returns: The route's unique ID, usable with ``removeRoute(id:)``.
    @discardableResult
    public func stubJSON(
        _ method: HTTPMethod? = nil,
        _ path: String,
        json: String,
        status: HTTPStatus = .ok
    ) -> String {
        let response = MockHTTPResponse.json(json, status: status)
        return stub(method, path, response: response)
    }

    /// Register a static image response loaded from a bundle resource.
    ///
    /// The content type is inferred from the file extension.
    /// Supported formats: `png`, `jpg`, `gif`, `webp`, `svg`, `heic`, `tiff`, `bmp`, `ico`.
    ///
    /// ```swift
    /// try await server.stubImage(.GET, "/avatar.png",
    ///     named: "avatar.png", in: .module)
    /// ```
    ///
    /// - Parameters:
    ///   - method: HTTP method to match, or `nil` for any method.
    ///   - path: Exact path to match.
    ///   - filename: The image file name in the bundle (e.g., `"avatar.png"`).
    ///   - bundle: The bundle containing the file. Use `.module` for SPM resources.
    ///   - status: HTTP status code. Defaults to `.ok`.
    /// - Returns: The route's unique ID, usable with ``removeRoute(id:)``.
    /// - Throws: ``MockServerError/invalidRequest(_:)`` if the file is not found.
    @discardableResult
    public func stubImage(
        _ method: HTTPMethod? = nil,
        _ path: String,
        named filename: String,
        in bundle: Bundle,
        status: HTTPStatus = .ok
    ) throws -> String {
        guard let response = MockHTTPResponse.imageFile(named: filename, in: bundle, status: status) else {
            throw MockServerError.invalidRequest("Image fixture not found: \(filename)")
        }
        return stub(method, path, response: response)
    }

    // MARK: - Route Management

    /// Remove a previously registered route by its ID.
    ///
    /// The ID is returned by all registration methods (``register(_:_:handler:)``,
    /// ``stub(_:_:response:)``, etc.).
    ///
    /// ```swift
    /// let routeID = await server.stubJSON(.GET, "/api/feature",
    ///     json: #"{"enabled": false}"#)
    ///
    /// // Later, remove it and register a different response
    /// await server.removeRoute(id: routeID)
    /// await server.stubJSON(.GET, "/api/feature",
    ///     json: #"{"enabled": true}"#)
    /// ```
    ///
    /// - Parameter id: The route ID to remove.
    public func removeRoute(id: String) {
        routes.removeAll { $0.id == id }
    }

    /// Remove all registered routes.
    ///
    /// After calling this, all requests will receive the default response
    /// until new routes are registered.
    public func removeAllRoutes() {
        routes.removeAll()
    }

    /// Set the default response returned when no registered route matches.
    ///
    /// The initial default is `404 Not Found`.
    ///
    /// ```swift
    /// await server.setDefaultResponse(
    ///     .json(#"{"error": "Not Found"}"#, status: .notFound))
    /// ```
    ///
    /// - Parameter response: The response to return for unmatched requests.
    public func setDefaultResponse(_ response: MockHTTPResponse) {
        defaultResponse = response
    }

    /// Set an artificial delay applied to all responses.
    ///
    /// Useful for testing loading states, timeouts, or slow-network behavior.
    /// Pass `nil` to remove the delay.
    ///
    /// ```swift
    /// await server.setResponseDelay(.milliseconds(500)) // 500ms delay
    /// // ... test loading state ...
    /// await server.setResponseDelay(nil) // remove delay
    /// ```
    ///
    /// - Parameter delay: The delay duration, or `nil` to respond immediately.
    public func setResponseDelay(_ delay: Duration?) {
        responseDelay = delay
    }

    // MARK: - Request Recording

    /// Clear all recorded requests.
    ///
    /// Useful when you want to verify requests for a specific phase of a test
    /// without interference from earlier requests.
    ///
    /// ```swift
    /// // Phase 1 of the test...
    /// await server.clearRecordedRequests()
    /// // Phase 2 — only new requests are recorded
    /// ```
    public func clearRecordedRequests() {
        recordedRequests.removeAll()
    }

    /// Get all recorded requests whose path matches exactly.
    ///
    /// ```swift
    /// let userRequests = await server.requests(matching: "/api/users")
    /// XCTAssertEqual(userRequests.count, 2)
    /// ```
    ///
    /// - Parameter path: The exact path to filter by.
    /// - Returns: All matching recorded requests, in order of receipt.
    public func requests(matching path: String) -> [RecordedRequest] {
        recordedRequests.filter { $0.request.path == path }
    }

    /// Get all recorded requests matching a specific method and path.
    ///
    /// ```swift
    /// let posts = await server.requests(method: .POST, path: "/api/users")
    /// XCTAssertEqual(posts.count, 1)
    ///
    /// let body = try posts[0].request.jsonBody(CreateUser.self)
    /// XCTAssertEqual(body.name, "Alice")
    /// ```
    ///
    /// - Parameters:
    ///   - method: The HTTP method to filter by.
    ///   - path: The exact path to filter by.
    /// - Returns: All matching recorded requests, in order of receipt.
    public func requests(
        method: HTTPMethod,
        path: String
    ) -> [RecordedRequest] {
        recordedRequests.filter {
            $0.request.method == method && $0.request.path == path
        }
    }

    /// Check whether at least one request matching the criteria was received.
    ///
    /// ```swift
    /// XCTAssertTrue(await server.didReceive(method: .POST, path: "/api/login"))
    /// XCTAssertFalse(await server.didReceive(path: "/api/admin"))
    /// ```
    ///
    /// - Parameters:
    ///   - method: HTTP method to match, or `nil` to match any method.
    ///   - path: The exact path to match.
    /// - Returns: `true` if at least one matching request was recorded.
    public func didReceive(
        method: HTTPMethod? = nil,
        path: String
    ) -> Bool {
        recordedRequests.contains { req in
            (method == nil || req.request.method == method) && req.request.path == path
        }
    }

    /// Wait until a request matching the criteria is received.
    ///
    /// Polls the recorded requests at the given interval until a match is found
    /// or the timeout expires. Useful for verifying requests triggered asynchronously.
    ///
    /// ```swift
    /// // Trigger an async operation that will POST to /api/analytics
    /// triggerAnalyticsFlush()
    ///
    /// let recorded = try await server.waitForRequest(
    ///     method: .POST,
    ///     path: "/api/analytics",
    ///     timeout: .seconds(5)
    /// )
    /// XCTAssertNotNil(recorded.request.body)
    /// ```
    ///
    /// - Parameters:
    ///   - method: HTTP method to match, or `nil` for any method.
    ///   - path: The exact path to match.
    ///   - timeout: Maximum time to wait. Defaults to 10 seconds.
    ///   - pollInterval: How often to check. Defaults to 100 milliseconds.
    /// - Returns: The first matching ``RecordedRequest``.
    /// - Throws: ``MockServerError/timeout`` if no match is found within the timeout.
    public func waitForRequest(
        method: HTTPMethod? = nil,
        path: String,
        timeout: Duration = .seconds(10),
        pollInterval: Duration = .milliseconds(100)
    ) async throws -> RecordedRequest {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if let match = recordedRequests.first(where: { req in
                (method == nil || req.request.method == method) && req.request.path == path
            }) {
                return match
            }
            try await Task.sleep(for: pollInterval)
        }
        throw MockServerError.timeout
    }

    // MARK: - Connection Handling (private)

    /// Match the route, record the request, and invoke the handler.
    /// This is actor-isolated but does NO blocking I/O — only lightweight state access.
    private func resolveResponse(for request: MockHTTPRequest) async -> MockHTTPResponse {
        let match = RouterEngine.match(request: request, routes: routes)

        recordedRequests.append(RecordedRequest(
            request: request,
            matchedRoute: match?.route.pattern.description
        ))

        if let match {
            do {
                return try await match.route.handler(request)
            } catch {
                return MockHTTPResponse.text(
                    "Handler Error: \(error)",
                    status: .internalServerError
                )
            }
        } else {
            return defaultResponse
        }
    }
}

// MARK: - Convenience Extensions

extension MockServer {

    /// Start the server and return its base URL.
    ///
    /// Convenience for test `setUp` when you need the URL immediately:
    ///
    /// ```swift
    /// let server = MockServer()
    /// let baseURL = try await server.startAndGetURL()
    /// // baseURL = "http://localhost:54321"
    /// ```
    ///
    /// - Returns: The server's base URL (e.g., `"http://localhost:54321"`).
    /// - Throws: ``MockServerError/alreadyRunning`` or ``MockServerError/bindFailed(_:)``.
    public func startAndGetURL() async throws -> String {
        try await start()
        return await baseURL
    }

    /// Create, start, and return a ready-to-use mock server.
    ///
    /// This is the recommended way to set up a server in tests — one line:
    ///
    /// ```swift
    /// let server = try await MockServer.create()
    /// await server.stubJSON(.GET, "/api/users", json: "[]")
    /// ```
    ///
    /// - Parameters:
    ///   - port: Port to listen on. Defaults to `0` (OS-assigned).
    ///   - defaultResponse: Response for unmatched routes. Defaults to `404`.
    /// - Returns: A started ``MockServer`` instance.
    /// - Throws: ``MockServerError/bindFailed(_:)`` if the port is unavailable.
    public static func create(
        port: UInt16 = 0,
        defaultResponse: MockHTTPResponse = .status(.notFound)
    ) async throws -> MockServer {
        let server = MockServer(port: port, defaultResponse: defaultResponse)
        try await server.start()
        return server
    }
}
