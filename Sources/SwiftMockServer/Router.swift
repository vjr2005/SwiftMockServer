// Router.swift
// SwiftMockServer
//
// Route matching with support for path parameters and wildcards.
// Uses Sendable closures for Swift 6 strict concurrency.

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

// MARK: - Router

/// Thread-safe route matching engine. Uses value types and pure functions.
public enum RouterEngine: Sendable {

    /// Find the first matching route for a request.
    public static func match(
        request: MockHTTPRequest,
        routes: [Route]
    ) -> RouteMatch? {
        for route in routes {
            // Check method if specified
            if let routeMethod = route.method, routeMethod != request.method {
                continue
            }

            // Check pattern
            switch route.pattern {
            case .exact(let path):
                if normalizePath(request.path) == normalizePath(path) {
                    return RouteMatch(route: route)
                }

            case .parameterized(let pattern):
                if let params = matchParameterized(
                    path: normalizePath(request.path),
                    pattern: normalizePath(pattern)
                ) {
                    return RouteMatch(route: route, pathParameters: params)
                }

            case .prefix(let prefix):
                if normalizePath(request.path).hasPrefix(normalizePath(prefix)) {
                    return RouteMatch(route: route)
                }

            case .any:
                return RouteMatch(route: route)
            }
        }
        return nil
    }

    /// Match a parameterized pattern like "/users/:id/posts/:postId".
    private static func matchParameterized(
        path: String,
        pattern: String
    ) -> [String: String]? {
        let pathComponents = path.split(separator: "/", omittingEmptySubsequences: true)
        let patternComponents = pattern.split(separator: "/", omittingEmptySubsequences: true)

        guard pathComponents.count == patternComponents.count else {
            return nil
        }

        var parameters: [String: String] = [:]

        for (pathComp, patternComp) in zip(pathComponents, patternComponents) {
            if patternComp.hasPrefix(":") {
                // This is a parameter
                let paramName = String(patternComp.dropFirst())
                parameters[paramName] = String(pathComp)
            } else if patternComp == "*" {
                // Wildcard — matches anything
                continue
            } else if pathComp != patternComp {
                return nil
            }
        }

        return parameters
    }

    /// Normalize a path by removing trailing slash (but keep leading slash).
    private static func normalizePath(_ path: String) -> String {
        var p = path
        if p.count > 1 && p.hasSuffix("/") {
            p = String(p.dropLast())
        }
        if !p.hasPrefix("/") {
            p = "/" + p
        }
        return p
    }
}
