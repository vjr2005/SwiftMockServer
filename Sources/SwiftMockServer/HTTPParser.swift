// HTTPParser.swift
// SwiftMockServer
//
// Parses raw HTTP data into MockHTTPRequest.
// All functions are pure/static — no mutable state, inherently concurrency-safe.

import Foundation

/// Stateless HTTP/1.1 request parser and response serializer.
///
/// All functions are pure/static — no mutable state, inherently thread-safe.
///
/// > Note: You normally don't call `HTTPParser` directly — ``MockServer`` uses it
/// > internally to parse incoming connections and serialize responses. It's public
/// > for advanced use cases like testing HTTP handling in isolation.
///
/// ```swift
/// // Parse raw HTTP data into a request
/// let data = "GET /api/users HTTP/1.1\r\nHost: localhost\r\n\r\n".data(using: .utf8)!
/// let request = try HTTPParser.parse(data)
/// print(request.method) // .GET
/// print(request.path)   // "/api/users"
///
/// // Serialize a response into raw HTTP data
/// let response = MockHTTPResponse.json(#"{"ok": true}"#)
/// let responseData = HTTPParser.serialize(response)
/// ```
public enum HTTPParser: Sendable {

    /// Parse raw HTTP/1.1 data into a ``MockHTTPRequest``.
    ///
    /// Extracts the method, path, query parameters, headers, and body.
    ///
    /// - Parameter data: Raw HTTP request data (UTF-8).
    /// - Returns: A parsed ``MockHTTPRequest``.
    /// - Throws: ``MockServerError/invalidRequest(_:)`` if the data is malformed.
    public static func parse(_ data: Data) throws -> MockHTTPRequest {
        guard let string = String(data: data, encoding: .utf8) else {
            throw MockServerError.invalidRequest("Cannot decode data as UTF-8")
        }

        // Split headers from body
        let components = string.components(separatedBy: "\r\n\r\n")
        guard let headerSection = components.first, !headerSection.isEmpty else {
            throw MockServerError.invalidRequest("Empty request")
        }

        var lines = headerSection.components(separatedBy: "\r\n")

        // Parse request line: METHOD /path HTTP/1.1
        guard let requestLine = lines.first else {
            throw MockServerError.invalidRequest("No request line")
        }
        lines.removeFirst()

        let requestParts = requestLine.split(separator: " ", maxSplits: 2).map(String.init)
        guard requestParts.count >= 2 else {
            throw MockServerError.invalidRequest("Malformed request line: \(requestLine)")
        }

        let methodString = requestParts[0].uppercased()
        guard let method = HTTPMethod(rawValue: methodString) else {
            throw MockServerError.invalidRequest("Unknown method: \(methodString)")
        }

        let rawPath = requestParts[1]

        // Parse path and query string
        let (path, queryParameters) = parsePath(rawPath)

        // Parse headers
        var headers: [String: String] = [:]
        for line in lines {
            let headerParts = line.split(separator: ":", maxSplits: 1)
            if headerParts.count == 2 {
                let key = headerParts[0].trimmingCharacters(in: .whitespaces)
                let value = headerParts[1].trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }

        // Parse body (everything after \r\n\r\n)
        var body: Data? = nil
        if components.count > 1 {
            let bodyString = components.dropFirst().joined(separator: "\r\n\r\n")
            if !bodyString.isEmpty {
                body = Data(bodyString.utf8)
            }
        }

        return MockHTTPRequest(
            method: method,
            path: path,
            queryParameters: queryParameters,
            headers: headers,
            body: body
        )
    }

    /// Split a raw path into the path component and query parameters.
    private static func parsePath(_ rawPath: String) -> (String, [String: String]) {
        let parts = rawPath.split(separator: "?", maxSplits: 1)
        let path = String(parts[0])

        var queryParameters: [String: String] = [:]
        if parts.count > 1 {
            let queryString = String(parts[1])
            let pairs = queryString.split(separator: "&")
            for pair in pairs {
                let kv = pair.split(separator: "=", maxSplits: 1)
                let key = String(kv[0]).removingPercentEncoding ?? String(kv[0])
                let value = kv.count > 1
                    ? (String(kv[1]).removingPercentEncoding ?? String(kv[1]))
                    : ""
                queryParameters[key] = value
            }
        }

        return (path, queryParameters)
    }

    /// Serialize a ``MockHTTPResponse`` into raw HTTP/1.1 data for sending over the wire.
    ///
    /// Automatically adds `Content-Length`, `Connection: close`, and `Server` headers
    /// if not already present.
    ///
    /// - Parameter response: The response to serialize.
    /// - Returns: Raw HTTP response data ready to write to a socket.
    public static func serialize(_ response: MockHTTPResponse) -> Data {
        var result = "HTTP/1.1 \(response.status.code) \(response.status.reason)\r\n"

        var headers = response.headers

        // Add Content-Length if body exists
        if let body = response.body {
            headers["Content-Length"] = "\(body.count)"
        } else {
            headers["Content-Length"] = "0"
        }

        // Add default headers
        if headers["Connection"] == nil {
            headers["Connection"] = "close"
        }
        if headers["Server"] == nil {
            headers["Server"] = "SwiftMockServer/1.0"
        }

        // Write headers
        for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
            result += "\(key): \(value)\r\n"
        }

        result += "\r\n"

        var data = Data(result.utf8)
        if let body = response.body {
            data.append(body)
        }
        return data
    }
}
