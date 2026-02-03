// MockHTTPRequest.swift
// SwiftMockServer

import Foundation

/// A parsed HTTP request received by the mock server.
///
/// Available inside route handlers to inspect the incoming request:
///
/// ```swift
/// await server.register(.POST, "/api/users") { request in
///     print(request.method)          // .POST
///     print(request.path)            // "/api/users"
///     print(request.headers)         // ["Content-Type": "application/json", ...]
///     print(request.queryParameters) // ["page": "1"] for /api/users?page=1
///
///     let user = try request.jsonBody(CreateUser.self)
///     return .status(.created)
/// }
/// ```
///
/// Also accessible through ``RecordedRequest`` for post-request verification.
public struct MockHTTPRequest: Sendable {
    /// The HTTP method (GET, POST, PUT, etc.).
    public let method: HTTPMethod

    /// The request path without query string (e.g., `"/api/users"`).
    public let path: String

    /// Parsed query parameters. For `/search?q=swift&page=1` this is `["q": "swift", "page": "1"]`.
    public let queryParameters: [String: String]

    /// HTTP headers as key-value pairs (e.g., `["Content-Type": "application/json"]`).
    public let headers: [String: String]

    /// Raw request body as `Data`, or `nil` if the request has no body.
    public let body: Data?

    /// Create a mock HTTP request.
    ///
    /// Normally you don't create these directly — the server parses them from incoming connections.
    /// Useful for unit-testing route handlers in isolation:
    ///
    /// ```swift
    /// let request = MockHTTPRequest(
    ///     method: .GET,
    ///     path: "/api/users",
    ///     queryParameters: ["page": "1"]
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - method: The HTTP method.
    ///   - path: The request path.
    ///   - queryParameters: Parsed query string parameters.
    ///   - headers: HTTP headers.
    ///   - body: Raw request body.
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

    /// Decode the request body as a JSON object.
    ///
    /// ```swift
    /// struct CreateUser: Codable, Sendable {
    ///     let name: String
    ///     let email: String
    /// }
    ///
    /// await server.register(.POST, "/api/users") { request in
    ///     let user = try request.jsonBody(CreateUser.self)
    ///     return try .json(["id": 1, "name": user.name], status: .created)
    /// }
    /// ```
    ///
    /// - Parameter type: The `Decodable` type to decode into.
    /// - Returns: The decoded value.
    /// - Throws: ``MockServerError/noBody`` if the request has no body,
    ///   or a `DecodingError` if the JSON doesn't match the type.
    public func jsonBody<T: Decodable & Sendable>(_ type: T.Type) throws -> T {
        guard let body else {
            throw MockServerError.noBody
        }
        return try JSONDecoder().decode(type, from: body)
    }

    /// The request body as a UTF-8 string, or `nil` if there is no body or it isn't valid UTF-8.
    ///
    /// ```swift
    /// await server.register(.POST, "/webhook") { request in
    ///     if let text = request.bodyString {
    ///         print("Received: \(text)")
    ///     }
    ///     return .status(.ok)
    /// }
    /// ```
    public var bodyString: String? {
        body.flatMap { String(data: $0, encoding: .utf8) }
    }
}
