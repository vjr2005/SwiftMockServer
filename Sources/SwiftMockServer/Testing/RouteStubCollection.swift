// RouteStubCollection.swift
// SwiftMockServer

/// A collection of static route stubs that can be registered in batch.
///
/// Define stubs using the ``RouteStubBuilder`` result builder for a declarative syntax:
///
/// ```swift
/// let stubs = RouteStubCollection {
///     RouteStubCollection.Stub(
///         method: .GET, path: "/api/users",
///         response: .json(#"[{"id": 1, "name": "Alice"}]"#)
///     )
///     RouteStubCollection.Stub(
///         method: .POST, path: "/api/users",
///         response: .status(.created)
///     )
/// }
///
/// await server.registerAll(stubs)
/// ```
///
/// The result builder supports `if/else`, `for-in` loops, and optional chaining:
///
/// ```swift
/// let stubs = RouteStubCollection {
///     for endpoint in ["/api/a", "/api/b"] {
///         RouteStubCollection.Stub(path: endpoint, response: .status(.ok))
///     }
///     if needsAuth {
///         RouteStubCollection.Stub(
///             method: .POST, path: "/api/login",
///             response: .json(#"{"token": "abc"}"#)
///         )
///     }
/// }
/// ```
///
/// Collections are `Sendable` — define them once and reuse across multiple tests.
public struct RouteStubCollection: Sendable {

    /// A single route stub: a method + path + static response.
    ///
    /// ```swift
    /// RouteStubCollection.Stub(
    ///     method: .GET,
    ///     path: "/api/users",
    ///     response: .json("[]")
    /// )
    /// ```
    public struct Stub: Sendable {
        /// The HTTP method to match, or `nil` for any method.
        let method: HTTPMethod?

        /// The exact path to match.
        let path: String

        /// The static response to return.
        let response: MockHTTPResponse

        /// Create a route stub.
        ///
        /// - Parameters:
        ///   - method: HTTP method to match, or `nil` for any method.
        ///   - path: Exact path to match.
        ///   - response: Static response to return.
        public init(method: HTTPMethod? = nil, path: String, response: MockHTTPResponse) {
            self.method = method
            self.path = path
            self.response = response
        }
    }

    /// The stubs in this collection.
    public var stubs: [Stub]

    /// Create a collection from an array of stubs.
    ///
    /// - Parameter stubs: The stubs to include. Defaults to empty.
    public init(_ stubs: [Stub] = []) {
        self.stubs = stubs
    }

    /// Create a collection using the ``RouteStubBuilder`` result builder.
    ///
    /// ```swift
    /// let stubs = RouteStubCollection {
    ///     RouteStubCollection.Stub(method: .GET, path: "/api/users", response: .json("[]"))
    ///     RouteStubCollection.Stub(method: .GET, path: "/api/config", response: .json(#"{"v":1}"#))
    /// }
    /// ```
    public init(@RouteStubBuilder builder: () -> [Stub]) {
        self.stubs = builder()
    }

    /// Append a stub to the collection.
    ///
    /// - Parameters:
    ///   - method: HTTP method to match, or `nil` for any method.
    ///   - path: Exact path to match.
    ///   - response: Static response to return.
    public mutating func add(
        _ method: HTTPMethod? = nil,
        _ path: String,
        response: MockHTTPResponse
    ) {
        stubs.append(Stub(method: method, path: path, response: response))
    }
}

/// Result builder for declarative ``RouteStubCollection`` construction.
///
/// Supports `if/else` conditionals, `for-in` loops, and optional chaining.
///
/// ```swift
/// let stubs = RouteStubCollection {
///     RouteStubCollection.Stub(method: .GET, path: "/a", response: .status(.ok))
///     if condition {
///         RouteStubCollection.Stub(method: .GET, path: "/b", response: .status(.ok))
///     }
/// }
/// ```
@resultBuilder
public enum RouteStubBuilder {
    public static func buildExpression(_ expression: RouteStubCollection.Stub) -> [RouteStubCollection.Stub] {
        [expression]
    }

    public static func buildBlock(_ components: [RouteStubCollection.Stub]...) -> [RouteStubCollection.Stub] {
        components.flatMap { $0 }
    }

    public static func buildArray(_ components: [[RouteStubCollection.Stub]]) -> [RouteStubCollection.Stub] {
        components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [RouteStubCollection.Stub]?) -> [RouteStubCollection.Stub] {
        component ?? []
    }

    public static func buildEither(first component: [RouteStubCollection.Stub]) -> [RouteStubCollection.Stub] {
        component
    }

    public static func buildEither(second component: [RouteStubCollection.Stub]) -> [RouteStubCollection.Stub] {
        component
    }
}

extension MockServer {

    /// Register all stubs from a ``RouteStubCollection`` at once.
    ///
    /// Each stub is registered as an exact-path route with the given static response.
    ///
    /// ```swift
    /// let stubs = RouteStubCollection {
    ///     RouteStubCollection.Stub(method: .GET, path: "/api/users", response: .json("[]"))
    ///     RouteStubCollection.Stub(method: .POST, path: "/api/users", response: .status(.created))
    /// }
    /// await server.registerAll(stubs)
    /// ```
    ///
    /// - Parameter collection: The collection of stubs to register.
    public func registerAll(_ collection: RouteStubCollection) {
        for stub in collection.stubs {
            let response = stub.response
            self.stub(stub.method, stub.path, response: response)
        }
    }
}
