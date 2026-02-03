// HTTPMethod.swift
// SwiftMockServer

/// HTTP request method. Value type, automatically Sendable.
public enum HTTPMethod: String, Sendable, Hashable, CaseIterable {
    case GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS, CONNECT, TRACE
}
