// MockServerAppConfig.swift
// SwiftMockServer

import Foundation

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
