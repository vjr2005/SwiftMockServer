// MockServer.swift
// SwiftMockServer
//
// The main mock HTTP server. Implemented as an `actor` for inherent
// Sendable compliance and thread-safe mutable state.
// Designed for parallel UI testing with multiple simultaneous simulators.

import Foundation

// MARK: - MockServer

/// A lightweight, embeddable HTTP mock server designed for iOS UI testing.
///
/// `MockServer` is an `actor`, which means:
/// - It's automatically `Sendable` (Swift 6 strict concurrency safe)
/// - All mutable state is protected by actor isolation
/// - It can be safely shared across concurrent test tasks
///
/// ## Usage
/// ```swift
/// let server = MockServer()
/// try await server.start()
///
/// await server.register(.GET, "/api/users") { _ in
///     .json("""
///     [{"id": 1, "name": "Alice"}]
///     """)
/// }
///
/// let port = await server.port
/// let app = XCUIApplication()
/// app.launchEnvironment["API_BASE_URL"] = "http://localhost:\(port)"
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

    /// Whether the server is currently running.
    public var isRunning: Bool { _isRunning }

    /// The port the server is listening on. Only valid after `start()`.
    public var port: UInt16 {
        get async {
            if let listener {
                return await listener.port
            }
            return requestedPort
        }
    }

    /// The base URL for this server (e.g., "http://localhost:8080").
    public var baseURL: String {
        get async {
            let p = await port
            return "http://127.0.0.1:\(p)"
        }
    }

    /// All recorded requests, in order of receipt.
    public var requests: [RecordedRequest] { recordedRequests }

    // MARK: - Init

    /// Create a new MockServer.
    /// - Parameters:
    ///   - port: Port to listen on. Use 0 (default) for automatic assignment.
    ///           Automatic assignment is recommended for parallel testing.
    ///   - defaultResponse: Response to send when no route matches. Defaults to 404.
    public init(
        port: UInt16 = 0,
        defaultResponse: MockHTTPResponse = .status(.notFound)
    ) {
        self.requestedPort = port
        self.defaultResponse = defaultResponse
    }

    // MARK: - Lifecycle

    /// Start the server. Binds to the configured port and begins accepting connections.
    ///
    /// When using port 0 (default), the OS assigns an available port automatically.
    /// This is the recommended approach for parallel testing — each test process
    /// gets its own unique port with zero configuration.
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
    public func stop() async {
        if let listener {
            await listener.stop()
        }
        listener = nil
        _isRunning = false
    }

    // MARK: - Route Registration

    /// Register a route with a handler.
    ///
    /// Routes are matched in LIFO order (last registered = highest priority).
    /// This allows overriding routes mid-test.
    ///
    /// - Parameters:
    ///   - method: HTTP method to match (nil matches all methods).
    ///   - path: Exact path to match.
    ///   - handler: Async handler that returns a response.
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

    /// Register a parameterized route (e.g., "/users/:id").
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

    /// Register a catch-all route.
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

    /// Register a static response for a route.
    @discardableResult
    public func stub(
        _ method: HTTPMethod? = nil,
        _ path: String,
        response: MockHTTPResponse
    ) -> String {
        let capturedResponse = response
        return register(method, path) { _ in capturedResponse }
    }

    /// Register a static JSON string response.
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

    /// Register a static image response loaded from a fixture file.
    ///
    /// ```swift
    /// try await server.stubImage(.GET, "/avatar.png",
    ///     named: "avatar.png", in: .module)
    /// ```
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

    /// Remove a route by its ID.
    public func removeRoute(id: String) {
        routes.removeAll { $0.id == id }
    }

    /// Remove all registered routes.
    public func removeAllRoutes() {
        routes.removeAll()
    }

    /// Set the default response for unmatched routes.
    public func setDefaultResponse(_ response: MockHTTPResponse) {
        defaultResponse = response
    }

    /// Set an artificial delay for all responses (useful for testing loading states).
    public func setResponseDelay(_ delay: Duration?) {
        responseDelay = delay
    }

    // MARK: - Request Recording

    /// Clear all recorded requests.
    public func clearRecordedRequests() {
        recordedRequests.removeAll()
    }

    /// Get recorded requests matching a path.
    public func requests(matching path: String) -> [RecordedRequest] {
        recordedRequests.filter { $0.request.path == path }
    }

    /// Get recorded requests matching a method and path.
    public func requests(
        method: HTTPMethod,
        path: String
    ) -> [RecordedRequest] {
        recordedRequests.filter {
            $0.request.method == method && $0.request.path == path
        }
    }

    /// Check if a specific request was received.
    public func didReceive(
        method: HTTPMethod? = nil,
        path: String
    ) -> Bool {
        recordedRequests.contains { req in
            (method == nil || req.request.method == method) && req.request.path == path
        }
    }

    /// Wait until a request matching the criteria is received (with timeout).
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

    /// Start the server and return the base URL. Convenience for test setUp.
    public func startAndGetURL() async throws -> String {
        try await start()
        return await baseURL
    }

    /// Create, start, and return a configured MockServer.
    /// Ideal for one-line test setup.
    public static func create(
        port: UInt16 = 0,
        defaultResponse: MockHTTPResponse = .status(.notFound)
    ) async throws -> MockServer {
        let server = MockServer(port: port, defaultResponse: defaultResponse)
        try await server.start()
        return server
    }
}
