// MockServerDetector.swift
// SwiftMockServer

import Foundation

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
        isUsingMockServer(arguments: ProcessInfo.processInfo.arguments)
    }

    /// Get the mock server base URL from launch environment.
    public static var baseURL: String? {
        baseURL(from: ProcessInfo.processInfo.environment)
    }

    /// Get the mock server port from launch environment.
    public static var port: UInt16? {
        port(from: ProcessInfo.processInfo.environment)
    }

    // MARK: - Testable helpers

    /// Check if the given arguments contain the mock server flag.
    public static func isUsingMockServer(
        arguments: [String],
        flag: String = "-useMockServer"
    ) -> Bool {
        arguments.contains(flag)
    }

    /// Extract the mock server base URL from the given environment.
    public static func baseURL(
        from environment: [String: String],
        key: String = "MOCK_SERVER_URL"
    ) -> String? {
        environment[key]
    }

    /// Extract the mock server port from the given environment.
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
