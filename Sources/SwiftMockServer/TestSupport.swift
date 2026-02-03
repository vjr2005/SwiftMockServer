// TestSupport.swift
// SwiftMockServer
//
// XCTest integration helpers for UI testing.
// Provides ergonomic APIs for XCUITest scenarios with parallel simulator support.

import Foundation

// MARK: - UITest Configuration

/// Configuration for launching the app under test with the mock server.
/// Sendable struct — safe to pass across concurrency boundaries.
public struct MockServerAppConfig: Sendable {
    /// The base URL of the mock server (e.g., "http://localhost:12345").
    public let baseURL: String

    /// The port the mock server is running on.
    public let port: UInt16

    /// Launch arguments to pass to the app.
    public let launchArguments: [String]

    /// Launch environment variables to pass to the app.
    public let launchEnvironment: [String: String]

    public init(
        baseURL: String,
        port: UInt16,
        baseURLEnvironmentKey: String = "MOCK_SERVER_URL",
        portEnvironmentKey: String = "MOCK_SERVER_PORT",
        useMockServerArgument: String = "-useMockServer",
        additionalArguments: [String] = [],
        additionalEnvironment: [String: String] = [:]
    ) {
        self.baseURL = baseURL
        self.port = port

        var args = [useMockServerArgument]
        args.append(contentsOf: additionalArguments)
        self.launchArguments = args

        var env: [String: String] = [
            baseURLEnvironmentKey: baseURL,
            portEnvironmentKey: "\(port)"
        ]
        for (key, value) in additionalEnvironment {
            env[key] = value
        }
        self.launchEnvironment = env
    }
}

extension MockServer {

    /// Generate app launch configuration for this server.
    ///
    /// Use with XCUIApplication:
    /// ```swift
    /// let config = await server.appConfig()
    /// let app = XCUIApplication()
    /// app.launchArguments += config.launchArguments
    /// app.launchEnvironment.merge(config.launchEnvironment) { _, new in new }
    /// app.launch()
    /// ```
    public func appConfig(
        baseURLEnvironmentKey: String = "MOCK_SERVER_URL",
        portEnvironmentKey: String = "MOCK_SERVER_PORT",
        useMockServerArgument: String = "-useMockServer"
    ) async -> MockServerAppConfig {
        let url = await baseURL
        let p = await port
        return MockServerAppConfig(
            baseURL: url,
            port: p,
            baseURLEnvironmentKey: baseURLEnvironmentKey,
            portEnvironmentKey: portEnvironmentKey,
            useMockServerArgument: useMockServerArgument
        )
    }
}

// MARK: - Batch Route Registration

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
    public static func buildBlock(_ components: RouteStubCollection.Stub...) -> [RouteStubCollection.Stub] {
        components
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

// MARK: - JSON File Loading

extension MockHTTPResponse {

    /// Create a JSON response from a file in the test bundle.
    /// Useful for loading fixture files.
    public static func jsonFile(
        named filename: String,
        in bundle: Bundle,
        status: HTTPStatus = .ok
    ) -> MockHTTPResponse? {
        let name: String
        let ext: String
        if filename.contains(".") {
            let parts = filename.split(separator: ".", maxSplits: 1)
            name = String(parts[0])
            ext = String(parts[1])
        } else {
            name = filename
            ext = "json"
        }

        guard let url = bundle.url(forResource: name, withExtension: ext),
              let data = try? Data(contentsOf: url) else {
            return nil
        }

        return MockHTTPResponse(
            status: status,
            headers: ["Content-Type": "application/json; charset=utf-8"],
            body: data
        )
    }
}

// MARK: - App-Side Helper

/// Helper code to use in your app target (not the test target).
/// Include in your app under `#if DEBUG`.
///
/// ```swift
/// #if DEBUG
/// if MockServerDetector.isUsingMockServer {
///     let baseURL = MockServerDetector.baseURL ?? "http://localhost:8080"
///     APIClient.shared.baseURL = URL(string: baseURL)!
/// }
/// #endif
/// ```
public enum MockServerDetector: Sendable {

    /// Check if the app was launched with the mock server flag.
    public static var isUsingMockServer: Bool {
        ProcessInfo.processInfo.arguments.contains("-useMockServer")
    }

    /// Get the mock server base URL from launch environment.
    public static var baseURL: String? {
        ProcessInfo.processInfo.environment["MOCK_SERVER_URL"]
    }

    /// Get the mock server port from launch environment.
    public static var port: UInt16? {
        guard let portString = ProcessInfo.processInfo.environment["MOCK_SERVER_PORT"],
              let port = UInt16(portString) else {
            return nil
        }
        return port
    }
}
