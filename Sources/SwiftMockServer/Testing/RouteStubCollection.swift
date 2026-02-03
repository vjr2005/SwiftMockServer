// RouteStubCollection.swift
// SwiftMockServer

/// A collection of route stubs that can be registered together.
/// Sendable — safe to define in one place and reuse across tests.
public struct RouteStubCollection: Sendable {
    public struct Stub: Sendable {
        let method: HTTPMethod?
        let path: String
        let response: MockHTTPResponse

        public init(method: HTTPMethod? = nil, path: String, response: MockHTTPResponse) {
            self.method = method
            self.path = path
            self.response = response
        }
    }

    public var stubs: [Stub]

    public init(_ stubs: [Stub] = []) {
        self.stubs = stubs
    }

    public init(@RouteStubBuilder builder: () -> [Stub]) {
        self.stubs = builder()
    }

    public mutating func add(
        _ method: HTTPMethod? = nil,
        _ path: String,
        response: MockHTTPResponse
    ) {
        stubs.append(Stub(method: method, path: path, response: response))
    }
}

/// Result builder for ergonomic batch route definition.
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

    /// Register all stubs from a collection.
    public func registerAll(_ collection: RouteStubCollection) {
        for stub in collection.stubs {
            let response = stub.response
            self.stub(stub.method, stub.path, response: response)
        }
    }
}
