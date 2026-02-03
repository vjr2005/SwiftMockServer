// MockServerError.swift
// SwiftMockServer

/// Errors thrown by ``MockServer`` operations.
///
/// ```swift
/// do {
///     try await server.start()
/// } catch MockServerError.alreadyRunning {
///     // Server was already started
/// } catch MockServerError.bindFailed(let reason) {
///     // Port is in use or unavailable
/// }
/// ```
public enum MockServerError: Error, Sendable, CustomStringConvertible {
    /// The server could not bind to the requested port (e.g., port already in use).
    case bindFailed(String)

    /// The server could not start listening for connections.
    case listenFailed(String)

    /// ``MockServer/start()`` was called on a server that is already running.
    case alreadyRunning

    /// An operation was attempted on a server that hasn't been started.
    case notRunning

    /// ``MockHTTPRequest/jsonBody(_:)`` was called on a request with no body.
    case noBody

    /// The incoming data could not be parsed as a valid HTTP request.
    case invalidRequest(String)

    /// The requested port is unavailable (e.g., already bound by another process).
    case portUnavailable(UInt16)

    /// ``MockServer/waitForRequest(method:path:timeout:pollInterval:)`` timed out
    /// before a matching request was received.
    case timeout

    public var description: String {
        switch self {
        case .bindFailed(let msg): return "Bind failed: \(msg)"
        case .listenFailed(let msg): return "Listen failed: \(msg)"
        case .alreadyRunning: return "Server is already running"
        case .notRunning: return "Server is not running"
        case .noBody: return "Request has no body"
        case .invalidRequest(let msg): return "Invalid request: \(msg)"
        case .portUnavailable(let port): return "Port \(port) is unavailable"
        case .timeout: return "Operation timed out"
        }
    }
}
