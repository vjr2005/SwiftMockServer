// RouterEngine.swift
// SwiftMockServer

/// Stateless route matching engine.
///
/// Matches a ``MockHTTPRequest`` against an ordered list of ``Route``s.
/// Thread-safe by design — all functions are pure/static with no mutable state.
///
/// Routes are evaluated in array order (the server inserts new routes at index 0,
/// giving LIFO semantics). The first match wins.
///
/// ```swift
/// let routes: [Route] = [...]
/// let request = MockHTTPRequest(method: .GET, path: "/api/users")
///
/// if let match = RouterEngine.match(request: request, routes: routes) {
///     let response = try await match.route.handler(request)
/// }
/// ```
///
/// > Note: You normally don't call `RouterEngine` directly — ``MockServer``
/// > uses it internally. It's public for advanced use cases like custom routing logic.
public enum RouterEngine: Sendable {

    /// Find the first matching route for a request.
    ///
    /// Iterates through `routes` in order, checking method and pattern.
    /// Returns the first ``RouteMatch`` found, or `nil` if no route matches.
    ///
    /// - Parameters:
    ///   - request: The incoming HTTP request to match.
    ///   - routes: An ordered array of routes to match against.
    /// - Returns: A ``RouteMatch`` with the matched route and any path parameters,
    ///   or `nil` if no route matches.
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
