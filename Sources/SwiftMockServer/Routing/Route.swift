// Route.swift
// SwiftMockServer

import Foundation

// MARK: - Route Handler

/// A Sendable closure that receives a request and returns a response.
/// This is the core handler type — fully compatible with Swift 6 strict concurrency.
public typealias RouteHandler = @Sendable (MockHTTPRequest) async throws -> MockHTTPResponse

// MARK: - Route Definition

/// A registered route with its matcher and handler. Fully Sendable.
public struct Route: Sendable {
    public let id: String
    public let method: HTTPMethod?
    public let pattern: RoutePattern
    public let handler: RouteHandler

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

/// Describes how to match a URL path. Value type → Sendable.
public enum RoutePattern: Sendable, CustomStringConvertible {
    /// Exact path match (e.g., "/api/users")
    case exact(String)

    /// Path with parameters (e.g., "/api/users/:id")
    /// Parameters are extracted and available via `pathParameters` in the match result.
    case parameterized(String)

    /// Prefix match (e.g., "/api/" matches "/api/anything")
    case prefix(String)

    /// Match any path
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

/// Result of matching a request against a route. Sendable value type.
public struct RouteMatch: Sendable {
    public let route: Route
    public let pathParameters: [String: String]

    public init(route: Route, pathParameters: [String: String] = [:]) {
        self.route = route
        self.pathParameters = pathParameters
    }
}
