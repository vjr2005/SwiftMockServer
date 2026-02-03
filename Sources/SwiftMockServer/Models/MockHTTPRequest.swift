// MockHTTPRequest.swift
// SwiftMockServer

import Foundation

/// Parsed HTTP request. All properties are value types → Sendable.
public struct MockHTTPRequest: Sendable {
    public let method: HTTPMethod
    public let path: String
    public let queryParameters: [String: String]
    public let headers: [String: String]
    public let body: Data?

    public init(
        method: HTTPMethod,
        path: String,
        queryParameters: [String: String] = [:],
        headers: [String: String] = [:],
        body: Data? = nil
    ) {
        self.method = method
        self.path = path
        self.queryParameters = queryParameters
        self.headers = headers
        self.body = body
    }

    /// Decode body as JSON.
    public func jsonBody<T: Decodable & Sendable>(_ type: T.Type) throws -> T {
        guard let body else {
            throw MockServerError.noBody
        }
        return try JSONDecoder().decode(type, from: body)
    }

    /// Body as UTF-8 string.
    public var bodyString: String? {
        body.flatMap { String(data: $0, encoding: .utf8) }
    }
}
