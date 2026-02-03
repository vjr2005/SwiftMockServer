// RouterEngine.swift
// SwiftMockServer

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
