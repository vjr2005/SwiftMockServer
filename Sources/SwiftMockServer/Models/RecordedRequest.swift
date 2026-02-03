// RecordedRequest.swift
// SwiftMockServer

import Foundation

/// A recorded incoming request with timestamp. Sendable value type.
public struct RecordedRequest: Sendable {
    public let request: MockHTTPRequest
    public let timestamp: Date
    public let matchedRoute: String?

    public init(request: MockHTTPRequest, timestamp: Date = Date(), matchedRoute: String? = nil) {
        self.request = request
        self.timestamp = timestamp
        self.matchedRoute = matchedRoute
    }
}
