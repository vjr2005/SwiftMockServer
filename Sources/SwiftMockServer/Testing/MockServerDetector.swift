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
