// Route.swift
// SwiftMockServer

import Foundation

// MARK: - Route Handler

/// An async closure that receives a ``MockHTTPRequest`` and returns a ``MockHTTPResponse``.
///
/// This is the handler type used by all route registration methods. It is `@Sendable`
/// and fully compatible with Swift 6 strict concurrency.
///
/// ```swift
/// // As a closure
/// await server.register(.GET, "/api/users") { request in
///     .json(#"[{"id": 1}]"#)
/// }
///
/// // As a named function
/// func handleUsers(_ request: MockHTTPRequest) async throws -> MockHTTPResponse {
///     let page = request.queryParameters["page"] ?? "1"
///     return .json(#"{"page": \#(page)}"#)
/// }
/// await server.register(.GET, "/api/users", handler: handleUsers)
/// ```
public typealias RouteHandler = @Sendable (MockHTTPRequest) async throws -> MockHTTPResponse

// MARK: - Route Definition

/// A registered route combining an HTTP method filter, a URL pattern, and a handler.
///
/// Routes are created automatically when you call ``MockServer/register(_:_:handler:)``
/// and related methods. You can also create them directly for use with ``RouterEngine``:
///
/// ```swift
/// let route = Route(
///     method: .GET,
///     pattern: .exact("/api/users"),
///     handler: { _ in .json("[]") }
/// )
/// ```
///
/// Each route has a unique ``id`` (auto-generated UUID by default) that can be used
/// to remove it later via ``MockServer/removeRoute(id:)``.
public struct Route: Sendable {
    /// Unique identifier for this route. Used with ``MockServer/removeRoute(id:)``.
    public let id: String

    /// The HTTP method this route matches, or `nil` to match any method.
    public let method: HTTPMethod?

    /// The URL pattern used for matching (exact, parameterized, prefix, or catch-all).
    public let pattern: RoutePattern

    /// The async handler that produces a response for matched requests.
    public let handler: RouteHandler

    /// Create a route.
    ///
    /// - Parameters:
    ///   - id: Unique identifier. Defaults to a new UUID string.
    ///   - method: HTTP method to match, or `nil` for any method.
    ///   - pattern: The URL matching pattern.
    ///   - handler: The async handler that produces a response.
    public init(
        id: String = UUID().uuidString,
        method: HTTPMethod? = nil,
        pattern: RoutePattern,
        handler: @escaping RouteHandler
    ) {
        self.id = id
        self.method = method
        self.pattern = pattern
        self.handler = handler
    }
}

// MARK: - Route Pattern

/// Describes how a route matches incoming URL paths.
///
/// Four matching strategies are available, in order of specificity:
///
/// ```swift
/// // 1. Exact — matches only "/api/users"
/// await server.register(.GET, "/api/users") { ... }
///
/// // 2. Parameterized — matches "/api/users/42", "/api/users/abc", etc.
/// await server.registerParameterized(.GET, "/api/users/:id") { ... }
///
/// // 3. Prefix — matches "/static/css/app.css", "/static/js/main.js", etc.
/// await server.registerPrefix(.GET, "/static/") { ... }
///
/// // 4. Catch-all — matches any path not handled above
/// await server.registerCatchAll { ... }
/// ```
///
/// Routes are matched **LIFO** (last registered wins), so you can override
/// a route by registering a new one for the same path.
public enum RoutePattern: Sendable, CustomStringConvertible {
    /// Matches only the exact path.
    ///
    /// ```swift
    /// // Matches "/api/users" but NOT "/api/users/1" or "/api/users/"
    /// .exact("/api/users")
    /// ```
    case exact(String)

    /// Matches a path template with named `:parameters`.
    ///
    /// Parameters are extracted into ``RouteMatch/pathParameters``.
    ///
    /// ```swift
    /// // Matches "/api/users/42" → pathParameters: ["id": "42"]
    /// .parameterized("/api/users/:id")
    ///
    /// // Multiple parameters: "/posts/5/comments/12"
    /// .parameterized("/posts/:postId/comments/:commentId")
    /// ```
    case parameterized(String)

    /// Matches any path that starts with the given prefix.
    ///
    /// ```swift
    /// // Matches "/static/css/app.css", "/static/js/main.js", etc.
    /// .prefix("/static/")
    /// ```
    case prefix(String)

    /// Matches any path. Used for catch-all routes.
    ///
    /// ```swift
    /// // Matches everything not handled by other routes
    /// .any
    /// ```
    case any

    public var description: String {
        switch self {
        case .exact(let path): return "exact(\(path))"
        case .parameterized(let pattern): return "parameterized(\(pattern))"
        case .prefix(let prefix): return "prefix(\(prefix))"
        case .any: return "any"
        }
    }
}

// MARK: - Route Match Result

/// The result of successfully matching a request against a ``Route``.
///
/// Contains the matched route and any extracted path parameters (for parameterized routes).
///
/// ```swift
/// let match = RouterEngine.match(request: request, routes: routes)
/// if let match {
///     print(match.route.pattern)       // e.g., "parameterized(/users/:id)"
///     print(match.pathParameters["id"]) // e.g., "42"
///     let response = try await match.route.handler(request)
/// }
/// ```
public struct RouteMatch: Sendable {
    /// The route that matched the request.
    public let route: Route

    /// Extracted path parameters for parameterized routes (e.g., `["id": "42"]`).
    /// Empty for exact, prefix, and catch-all routes.
    public let pathParameters: [String: String]

    /// Create a route match result.
    ///
    /// - Parameters:
    ///   - route: The matched route.
    ///   - pathParameters: Extracted parameters. Defaults to empty.
    public init(route: Route, pathParameters: [String: String] = [:]) {
        self.route = route
        self.pathParameters = pathParameters
    }
}
