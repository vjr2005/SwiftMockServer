// MockHTTPResponse.swift
// SwiftMockServer

import Foundation

/// HTTP response to send back. All properties are value types → Sendable.
public struct MockHTTPResponse: Sendable {
    public var status: HTTPStatus
    public var headers: [String: String]
    public var body: Data?

    public init(
        status: HTTPStatus = .ok,
        headers: [String: String] = [:],
        body: Data? = nil
    ) {
        self.status = status
        self.headers = headers
        self.body = body
    }

    // MARK: - Convenience builders

    /// Create a JSON response from an Encodable value.
    public static func json<T: Encodable & Sendable>(
        _ value: T,
        status: HTTPStatus = .ok,
        encoder: JSONEncoder = JSONEncoder()
    ) throws -> MockHTTPResponse {
        let data = try encoder.encode(value)
        return MockHTTPResponse(
            status: status,
            headers: ["Content-Type": "application/json; charset=utf-8"],
            body: data
        )
    }

    /// Create a JSON response from a raw string.
    public static func json(
        _ rawJSON: String,
        status: HTTPStatus = .ok
    ) -> MockHTTPResponse {
        MockHTTPResponse(
            status: status,
            headers: ["Content-Type": "application/json; charset=utf-8"],
            body: Data(rawJSON.utf8)
        )
    }

    /// Create a plain text response.
    public static func text(
        _ string: String,
        status: HTTPStatus = .ok
    ) -> MockHTTPResponse {
        MockHTTPResponse(
            status: status,
            headers: ["Content-Type": "text/plain; charset=utf-8"],
            body: Data(string.utf8)
        )
    }

    /// Create an HTML response.
    public static func html(
        _ string: String,
        status: HTTPStatus = .ok
    ) -> MockHTTPResponse {
        MockHTTPResponse(
            status: status,
            headers: ["Content-Type": "text/html; charset=utf-8"],
            body: Data(string.utf8)
        )
    }

    /// Create a response with only a status code.
    public static func status(_ status: HTTPStatus) -> MockHTTPResponse {
        MockHTTPResponse(status: status)
    }

    /// Create a response from a file's data.
    public static func data(
        _ data: Data,
        contentType: String,
        status: HTTPStatus = .ok
    ) -> MockHTTPResponse {
        MockHTTPResponse(
            status: status,
            headers: ["Content-Type": contentType],
            body: data
        )
    }
}
