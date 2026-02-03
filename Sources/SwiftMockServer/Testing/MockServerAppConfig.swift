// MockServerAppConfig.swift
// SwiftMockServer

import Foundation

/// Configuration for launching an app under test with ``MockServer``.
///
/// Contains `launchArguments` and `launchEnvironment` ready to pass to `XCUIApplication`.
/// The app target uses ``MockServerDetector`` to read these values at runtime.
///
/// ```swift
/// // In your XCUITest:
/// let config = await server.appConfig()
///
/// let app = XCUIApplication()
/// app.launchArguments += config.launchArguments
/// app.launchEnvironment.merge(config.launchEnvironment) { _, new in new }
/// app.launch()
/// ```
///
/// By default, the config sets:
/// - Launch argument: `"-useMockServer"`
/// - Environment: `"MOCK_SERVER_URL"` → the server's base URL
/// - Environment: `"MOCK_SERVER_PORT"` → the server's port number
///
/// These keys match the defaults in ``MockServerDetector``.
public struct MockServerAppConfig: Sendable {
    /// The base URL of the mock server (e.g., `"http://[::1]:12345"`).
    public let baseURL: String

    /// The port the mock server is listening on.
    public let port: UInt16

    /// Launch arguments to pass to `XCUIApplication.launchArguments`.
    /// Contains the mock server flag (default: `"-useMockServer"`).
    public let launchArguments: [String]

    /// Environment variables to pass to `XCUIApplication.launchEnvironment`.
    /// Contains the base URL and port keyed by their configured names.
    public let launchEnvironment: [String: String]

    /// Create an app configuration manually.
    ///
    /// Prefer using ``MockServer/appConfig(baseURLEnvironmentKey:portEnvironmentKey:useMockServerArgument:)``
    /// which fills in `baseURL` and `port` automatically.
    ///
    /// - Parameters:
    ///   - baseURL: The mock server's base URL.
    ///   - port: The mock server's port.
    ///   - baseURLEnvironmentKey: Environment key for the base URL. Defaults to `"MOCK_SERVER_URL"`.
    ///   - portEnvironmentKey: Environment key for the port. Defaults to `"MOCK_SERVER_PORT"`.
    ///   - useMockServerArgument: Launch argument flag. Defaults to `"-useMockServer"`.
    ///   - additionalArguments: Extra launch arguments to include.
    ///   - additionalEnvironment: Extra environment variables to include.
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

    /// Generate a ``MockServerAppConfig`` with this server's URL and port.
    ///
    /// The returned config is ready to pass to `XCUIApplication`:
    ///
    /// ```swift
    /// let config = await server.appConfig()
    ///
    /// let app = XCUIApplication()
    /// app.launchArguments += config.launchArguments
    /// app.launchEnvironment.merge(config.launchEnvironment) { _, new in new }
    /// app.launch()
    /// ```
    ///
    /// In your app target, use ``MockServerDetector`` to read these values.
    ///
    /// - Parameters:
    ///   - baseURLEnvironmentKey: Environment key for the base URL. Defaults to `"MOCK_SERVER_URL"`.
    ///   - portEnvironmentKey: Environment key for the port. Defaults to `"MOCK_SERVER_PORT"`.
    ///   - useMockServerArgument: Launch argument flag. Defaults to `"-useMockServer"`.
    /// - Returns: A ``MockServerAppConfig`` populated with the server's current URL and port.
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
