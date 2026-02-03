// MockHTTPResponse.swift
// SwiftMockServer

import Foundation

/// An HTTP response returned by a route handler.
///
/// Use the static builder methods to construct responses conveniently:
///
/// ```swift
/// // JSON from a raw string
/// .json(#"{"name": "Alice"}"#)
///
/// // JSON from an Encodable model
/// try .json(myUser, status: .created)
///
/// // Plain text
/// .text("Hello, world!")
///
/// // Status code only (no body)
/// .status(.noContent)
/// ```
///
/// For file-based responses, see ``jsonFile(named:in:status:)`` and
/// ``imageFile(named:in:status:)``.
public struct MockHTTPResponse: Sendable {
    /// The HTTP status code for this response.
    public var status: HTTPStatus

    /// Response headers. Content-Type is set automatically by the builder methods.
    public var headers: [String: String]

    /// The raw response body, or `nil` for body-less responses (e.g., `204 No Content`).
    public var body: Data?

    /// Create a response with full control over status, headers, and body.
    ///
    /// Prefer the static builder methods (``json(_:status:)-swift.type.method``,
    /// ``text(_:status:)``, etc.) for common cases.
    ///
    /// ```swift
    /// let response = MockHTTPResponse(
    ///     status: .ok,
    ///     headers: ["X-Custom": "value"],
    ///     body: Data("raw content".utf8)
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - status: HTTP status code. Defaults to `.ok` (200).
    ///   - headers: Response headers. Defaults to empty.
    ///   - body: Response body data. Defaults to `nil`.
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

    /// Create a JSON response from an `Encodable` value.
    ///
    /// Sets `Content-Type: application/json; charset=utf-8` automatically.
    ///
    /// ```swift
    /// struct User: Codable, Sendable {
    ///     let id: Int
    ///     let name: String
    /// }
    ///
    /// await server.register(.GET, "/api/user") { _ in
    ///     try .json(User(id: 1, name: "Alice"))
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - value: The `Encodable` value to serialize.
    ///   - status: HTTP status code. Defaults to `.ok`.
    ///   - encoder: A `JSONEncoder` to use. Defaults to a plain `JSONEncoder()`.
    /// - Returns: A response with the JSON-encoded body.
    /// - Throws: An `EncodingError` if the value cannot be encoded.
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

    /// Create a JSON response from a raw JSON string.
    ///
    /// The string is sent as-is — no validation is performed.
    /// Sets `Content-Type: application/json; charset=utf-8` automatically.
    ///
    /// ```swift
    /// await server.stub(.GET, "/api/users",
    ///     response: .json(#"[{"id": 1, "name": "Alice"}]"#))
    /// ```
    ///
    /// - Parameters:
    ///   - rawJSON: A raw JSON string.
    ///   - status: HTTP status code. Defaults to `.ok`.
    /// - Returns: A response with the JSON string as body.
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
    ///
    /// Sets `Content-Type: text/plain; charset=utf-8` automatically.
    ///
    /// ```swift
    /// await server.stub(.GET, "/health", response: .text("OK"))
    /// ```
    ///
    /// - Parameters:
    ///   - string: The text content.
    ///   - status: HTTP status code. Defaults to `.ok`.
    /// - Returns: A response with the text body.
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
    ///
    /// Sets `Content-Type: text/html; charset=utf-8` automatically.
    ///
    /// ```swift
    /// await server.stub(.GET, "/page",
    ///     response: .html("<h1>Hello</h1>"))
    /// ```
    ///
    /// - Parameters:
    ///   - string: The HTML content.
    ///   - status: HTTP status code. Defaults to `.ok`.
    /// - Returns: A response with the HTML body.
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

    /// Create a body-less response with only a status code.
    ///
    /// ```swift
    /// // Simulate a 204 No Content
    /// await server.stub(.DELETE, "/api/users/1", response: .status(.noContent))
    ///
    /// // Simulate a 500 Internal Server Error
    /// await server.stub(.POST, "/api/pay", response: .status(.internalServerError))
    /// ```
    ///
    /// - Parameter status: The HTTP status code.
    /// - Returns: A response with no body.
    public static func status(_ status: HTTPStatus) -> MockHTTPResponse {
        MockHTTPResponse(status: status)
    }

    /// Create a response from raw data with an explicit content type.
    ///
    /// ```swift
    /// let pdf = try Data(contentsOf: pdfURL)
    /// await server.stub(.GET, "/report.pdf",
    ///     response: .data(pdf, contentType: "application/pdf"))
    /// ```
    ///
    /// - Parameters:
    ///   - data: The raw response body.
    ///   - contentType: The MIME type (e.g., `"application/pdf"`).
    ///   - status: HTTP status code. Defaults to `.ok`.
    /// - Returns: A response with the given data and content type.
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
