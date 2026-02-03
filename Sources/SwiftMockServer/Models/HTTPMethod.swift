// HTTPMethod.swift
// SwiftMockServer

/// Standard HTTP request methods.
///
/// Used to specify which HTTP method a route should match. Pass `nil` when registering
/// a route to match any method.
///
/// ```swift
/// // Match only GET requests
/// await server.register(.GET, "/api/users") { _ in .json("[]") }
///
/// // Match any method
/// await server.register(nil, "/api/health") { _ in .status(.ok) }
/// ```
///
/// Conforms to `Sendable`, `Hashable`, and `CaseIterable`.
public enum HTTPMethod: String, Sendable, Hashable, CaseIterable {
    /// HTTP GET — retrieve a resource.
    case GET
    /// HTTP POST — create a resource or submit data.
    case POST
    /// HTTP PUT — replace a resource entirely.
    case PUT
    /// HTTP PATCH — partially update a resource.
    case PATCH
    /// HTTP DELETE — remove a resource.
    case DELETE
    /// HTTP HEAD — like GET but without the response body.
    case HEAD
    /// HTTP OPTIONS — describe communication options.
    case OPTIONS
    /// HTTP CONNECT — establish a tunnel.
    case CONNECT
    /// HTTP TRACE — perform a loop-back test.
    case TRACE
}
