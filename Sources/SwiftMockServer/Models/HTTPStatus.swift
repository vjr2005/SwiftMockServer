// HTTPStatus.swift
// SwiftMockServer

/// An HTTP response status code with its reason phrase.
///
/// Use the predefined constants for common status codes, or create custom ones:
///
/// ```swift
/// // Using predefined constants
/// let response = MockHTTPResponse.status(.ok)
/// let error = MockHTTPResponse.status(.notFound)
///
/// // Custom status code
/// let teapot = HTTPStatus(code: 418, reason: "I'm a Teapot")
/// let response = MockHTTPResponse.status(teapot)
/// ```
///
/// Conforms to `Sendable`, `Hashable`, and `CustomStringConvertible`.
public struct HTTPStatus: Sendable, Hashable, CustomStringConvertible {
    /// The numeric HTTP status code (e.g., `200`, `404`).
    public let code: Int

    /// The human-readable reason phrase (e.g., `"OK"`, `"Not Found"`).
    public let reason: String

    /// A textual representation: `"200 OK"`, `"404 Not Found"`, etc.
    public var description: String { "\(code) \(reason)" }

    /// Create a custom HTTP status code.
    ///
    /// ```swift
    /// let custom = HTTPStatus(code: 418, reason: "I'm a Teapot")
    /// ```
    ///
    /// - Parameters:
    ///   - code: The numeric status code.
    ///   - reason: The human-readable reason phrase.
    public init(code: Int, reason: String) {
        self.code = code
        self.reason = reason
    }

    // MARK: - 2xx Success

    /// `200 OK` — Standard success response.
    public static let ok = HTTPStatus(code: 200, reason: "OK")
    /// `201 Created` — Resource was successfully created.
    public static let created = HTTPStatus(code: 201, reason: "Created")
    /// `202 Accepted` — Request accepted for processing but not yet completed.
    public static let accepted = HTTPStatus(code: 202, reason: "Accepted")
    /// `204 No Content` — Success with no response body.
    public static let noContent = HTTPStatus(code: 204, reason: "No Content")

    // MARK: - 3xx Redirection

    /// `301 Moved Permanently` — Resource has been permanently moved.
    public static let movedPermanently = HTTPStatus(code: 301, reason: "Moved Permanently")
    /// `302 Found` — Resource temporarily at a different URI.
    public static let found = HTTPStatus(code: 302, reason: "Found")
    /// `304 Not Modified` — Cached version is still valid.
    public static let notModified = HTTPStatus(code: 304, reason: "Not Modified")

    // MARK: - 4xx Client Errors

    /// `400 Bad Request` — Malformed request syntax.
    public static let badRequest = HTTPStatus(code: 400, reason: "Bad Request")
    /// `401 Unauthorized` — Authentication required.
    public static let unauthorized = HTTPStatus(code: 401, reason: "Unauthorized")
    /// `403 Forbidden` — Server refuses to authorize the request.
    public static let forbidden = HTTPStatus(code: 403, reason: "Forbidden")
    /// `404 Not Found` — Resource not found. Default response for unmatched routes.
    public static let notFound = HTTPStatus(code: 404, reason: "Not Found")
    /// `405 Method Not Allowed` — HTTP method not supported for this resource.
    public static let methodNotAllowed = HTTPStatus(code: 405, reason: "Method Not Allowed")
    /// `409 Conflict` — Request conflicts with current server state.
    public static let conflict = HTTPStatus(code: 409, reason: "Conflict")
    /// `422 Unprocessable Entity` — Request is well-formed but semantically invalid.
    public static let unprocessableEntity = HTTPStatus(code: 422, reason: "Unprocessable Entity")
    /// `429 Too Many Requests` — Rate limit exceeded.
    public static let tooManyRequests = HTTPStatus(code: 429, reason: "Too Many Requests")

    // MARK: - 5xx Server Errors

    /// `500 Internal Server Error` — Generic server error.
    public static let internalServerError = HTTPStatus(code: 500, reason: "Internal Server Error")
    /// `502 Bad Gateway` — Invalid response from upstream server.
    public static let badGateway = HTTPStatus(code: 502, reason: "Bad Gateway")
    /// `503 Service Unavailable` — Server temporarily unable to handle the request.
    public static let serviceUnavailable = HTTPStatus(code: 503, reason: "Service Unavailable")
    /// `504 Gateway Timeout` — Upstream server did not respond in time.
    public static let gatewayTimeout = HTTPStatus(code: 504, reason: "Gateway Timeout")
}
