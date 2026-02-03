// MockServerDetector.swift
// SwiftMockServer

import Foundation

/// Detects whether the app was launched by a test using ``MockServer``.
///
/// Use this in your **app target** (not the test target) to redirect network requests
/// to the mock server during UI tests. Wrap it in `#if DEBUG` to exclude from
/// release builds.
///
/// ```swift
/// import SwiftMockServer
///
/// @main
/// struct MyApp: App {
///     init() {
///         #if DEBUG
///         if MockServerDetector.isUsingMockServer,
///            let baseURL = MockServerDetector.baseURL {
///             APIClient.shared.baseURL = URL(string: baseURL)!
///         }
///         #endif
///     }
///
///     var body: some Scene {
///         WindowGroup { ContentView() }
///     }
/// }
/// ```
///
/// The detector reads launch arguments and environment variables set by
/// ``MockServerAppConfig`` (via ``MockServer/appConfig(baseURLEnvironmentKey:portEnvironmentKey:useMockServerArgument:)``).
public enum MockServerDetector: Sendable {

    /// Whether the app was launched with the `-useMockServer` flag.
    ///
    /// Returns `true` if `ProcessInfo.processInfo.arguments` contains the mock server flag.
    ///
    /// ```swift
    /// if MockServerDetector.isUsingMockServer {
    ///     // Redirect API calls to mock server
    /// }
    /// ```
    public static var isUsingMockServer: Bool {
        isUsingMockServer(arguments: ProcessInfo.processInfo.arguments)
    }

    /// The mock server's base URL from the launch environment (e.g., `"http://[::1]:54321"`).
    ///
    /// Returns `nil` if the `MOCK_SERVER_URL` environment variable is not set.
    ///
    /// ```swift
    /// if let url = MockServerDetector.baseURL {
    ///     APIClient.shared.baseURL = URL(string: url)!
    /// }
    /// ```
    public static var baseURL: String? {
        baseURL(from: ProcessInfo.processInfo.environment)
    }

    /// The mock server's port from the launch environment.
    ///
    /// Returns `nil` if the `MOCK_SERVER_PORT` environment variable is not set.
    public static var port: UInt16? {
        port(from: ProcessInfo.processInfo.environment)
    }

    // MARK: - Testable helpers

    /// Check whether the given arguments array contains the mock server flag.
    ///
    /// This overload accepts explicit arguments for unit-testing the detector itself.
    ///
    /// - Parameters:
    ///   - arguments: The arguments array to search (e.g., `CommandLine.arguments`).
    ///   - flag: The flag to look for. Defaults to `"-useMockServer"`.
    /// - Returns: `true` if the flag is present.
    public static func isUsingMockServer(
        arguments: [String],
        flag: String = "-useMockServer"
    ) -> Bool {
        arguments.contains(flag)
    }

    /// Extract the mock server base URL from the given environment dictionary.
    ///
    /// - Parameters:
    ///   - environment: The environment dictionary to search.
    ///   - key: The key to look up. Defaults to `"MOCK_SERVER_URL"`.
    /// - Returns: The base URL string, or `nil` if the key is not present.
    public static func baseURL(
        from environment: [String: String],
        key: String = "MOCK_SERVER_URL"
    ) -> String? {
        environment[key]
    }

    /// Extract the mock server port from the given environment dictionary.
    ///
    /// - Parameters:
    ///   - environment: The environment dictionary to search.
    ///   - key: The key to look up. Defaults to `"MOCK_SERVER_PORT"`.
    /// - Returns: The port number, or `nil` if the key is missing or not a valid `UInt16`.
    public static func port(
        from environment: [String: String],
        key: String = "MOCK_SERVER_PORT"
    ) -> UInt16? {
        guard let portString = environment[key],
              let port = UInt16(portString) else {
            return nil
        }
        return port
    }
}
