// HTTPStatus.swift
// SwiftMockServer

/// HTTP response status code. Value type, automatically Sendable.
public struct HTTPStatus: Sendable, Hashable, CustomStringConvertible {
    public let code: Int
    public let reason: String

    public var description: String { "\(code) \(reason)" }

    public init(code: Int, reason: String) {
        self.code = code
        self.reason = reason
    }

    // Common status codes
    public static let ok = HTTPStatus(code: 200, reason: "OK")
    public static let created = HTTPStatus(code: 201, reason: "Created")
    public static let accepted = HTTPStatus(code: 202, reason: "Accepted")
    public static let noContent = HTTPStatus(code: 204, reason: "No Content")
    public static let movedPermanently = HTTPStatus(code: 301, reason: "Moved Permanently")
    public static let found = HTTPStatus(code: 302, reason: "Found")
    public static let notModified = HTTPStatus(code: 304, reason: "Not Modified")
    public static let badRequest = HTTPStatus(code: 400, reason: "Bad Request")
    public static let unauthorized = HTTPStatus(code: 401, reason: "Unauthorized")
    public static let forbidden = HTTPStatus(code: 403, reason: "Forbidden")
    public static let notFound = HTTPStatus(code: 404, reason: "Not Found")
    public static let methodNotAllowed = HTTPStatus(code: 405, reason: "Method Not Allowed")
    public static let conflict = HTTPStatus(code: 409, reason: "Conflict")
    public static let unprocessableEntity = HTTPStatus(code: 422, reason: "Unprocessable Entity")
    public static let tooManyRequests = HTTPStatus(code: 429, reason: "Too Many Requests")
    public static let internalServerError = HTTPStatus(code: 500, reason: "Internal Server Error")
    public static let badGateway = HTTPStatus(code: 502, reason: "Bad Gateway")
    public static let serviceUnavailable = HTTPStatus(code: 503, reason: "Service Unavailable")
    public static let gatewayTimeout = HTTPStatus(code: 504, reason: "Gateway Timeout")
}
