// HTTPTypes.swift
// SwiftMockServer
//
// Sendable HTTP types for Swift 6 strict concurrency.

import Foundation

// MARK: - HTTP Method

/// HTTP request method. Value type, automatically Sendable.
public enum HTTPMethod: String, Sendable, Hashable, CaseIterable {
    case GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS, CONNECT, TRACE
}

// MARK: - HTTP Status

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

// MARK: - HTTP Request

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

// MARK: - HTTP Response

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

// MARK: - Errors

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

// MARK: - Recorded Request

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
