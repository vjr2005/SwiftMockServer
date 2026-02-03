// MockServerError.swift
// SwiftMockServer

/// Errors thrown by MockServer. Sendable by default (enum of value types).
public enum MockServerError: Error, Sendable, CustomStringConvertible {
    case bindFailed(String)
    case listenFailed(String)
    case alreadyRunning
    case notRunning
    case noBody
    case invalidRequest(String)
    case portUnavailable(UInt16)
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
