// MockHTTPResponse.swift
// SwiftMockServer

import Foundation

/// Image MIME content types for use with ``MockHTTPResponse/image(_:contentType:status:)``
/// and ``MockHTTPResponse/imageFile(named:in:status:)``.
///
/// Each case maps to a standard MIME type string via its ``rawValue``.
///
/// ```swift
/// let type = ImageContentType.png
/// print(type.rawValue)  // "image/png"
///
/// let fromExt = ImageContentType(fileExtension: "jpg")
/// print(fromExt?.rawValue)  // "image/jpeg"
/// ```
public enum ImageContentType: String, Sendable {
    case png  = "image/png"
    case jpeg = "image/jpeg"
    case gif  = "image/gif"
    case webp = "image/webp"
    case svg  = "image/svg+xml"
    case heic = "image/heic"
    case tiff = "image/tiff"
    case bmp  = "image/bmp"
    case ico  = "image/x-icon"

    /// Initialize from a file extension (e.g. "png", "jpg", "tif").
    /// Returns `nil` for unrecognized extensions.
    public init?(fileExtension ext: String) {
        switch ext.lowercased() {
        case "png":          self = .png
        case "jpg", "jpeg":  self = .jpeg
        case "gif":          self = .gif
        case "webp":         self = .webp
        case "svg":          self = .svg
        case "heic":         self = .heic
        case "tiff", "tif":  self = .tiff
        case "bmp":          self = .bmp
        case "ico":          self = .ico
        default:             return nil
        }
    }

    /// Initialize by detecting the image format from magic bytes in the data.
    /// Returns `nil` for unrecognized or empty data.
    ///
    /// Supported formats: PNG, JPEG, GIF, WebP, BMP, TIFF, ICO, HEIC.
    /// SVG is excluded because it is text-based and unreliable to detect from raw bytes.
    public init?(detecting data: Data) {
        guard data.count >= 2 else { return nil }

        // BMP: 42 4D
        if data[data.startIndex] == 0x42, data[data.startIndex + 1] == 0x4D {
            self = .bmp
            return
        }

        guard data.count >= 3 else { return nil }

        // JPEG: FF D8 FF
        if data[data.startIndex] == 0xFF,
           data[data.startIndex + 1] == 0xD8,
           data[data.startIndex + 2] == 0xFF {
            self = .jpeg
            return
        }

        guard data.count >= 4 else { return nil }

        // GIF: GIF8 (47 49 46 38)
        if data[data.startIndex] == 0x47,
           data[data.startIndex + 1] == 0x49,
           data[data.startIndex + 2] == 0x46,
           data[data.startIndex + 3] == 0x38 {
            self = .gif
            return
        }

        // TIFF little-endian: 49 49 2A 00
        if data[data.startIndex] == 0x49,
           data[data.startIndex + 1] == 0x49,
           data[data.startIndex + 2] == 0x2A,
           data[data.startIndex + 3] == 0x00 {
            self = .tiff
            return
        }

        // TIFF big-endian: 4D 4D 00 2A
        if data[data.startIndex] == 0x4D,
           data[data.startIndex + 1] == 0x4D,
           data[data.startIndex + 2] == 0x00,
           data[data.startIndex + 3] == 0x2A {
            self = .tiff
            return
        }

        // ICO: 00 00 01 00
        if data[data.startIndex] == 0x00,
           data[data.startIndex + 1] == 0x00,
           data[data.startIndex + 2] == 0x01,
           data[data.startIndex + 3] == 0x00 {
            self = .ico
            return
        }

        guard data.count >= 8 else { return nil }

        // PNG: 89 50 4E 47 0D 0A 1A 0A
        if data[data.startIndex] == 0x89,
           data[data.startIndex + 1] == 0x50,
           data[data.startIndex + 2] == 0x4E,
           data[data.startIndex + 3] == 0x47,
           data[data.startIndex + 4] == 0x0D,
           data[data.startIndex + 5] == 0x0A,
           data[data.startIndex + 6] == 0x1A,
           data[data.startIndex + 7] == 0x0A {
            self = .png
            return
        }

        guard data.count >= 12 else { return nil }

        // WebP: RIFF at 0..3 + WEBP at 8..11
        if data[data.startIndex] == 0x52,     // R
           data[data.startIndex + 1] == 0x49, // I
           data[data.startIndex + 2] == 0x46, // F
           data[data.startIndex + 3] == 0x46, // F
           data[data.startIndex + 8] == 0x57, // W
           data[data.startIndex + 9] == 0x45, // E
           data[data.startIndex + 10] == 0x42, // B
           data[data.startIndex + 11] == 0x50 { // P
            self = .webp
            return
        }

        // HEIC: ftyp at bytes 4..7, then brand at 8..11
        if data[data.startIndex + 4] == 0x66, // f
           data[data.startIndex + 5] == 0x74, // t
           data[data.startIndex + 6] == 0x79, // y
           data[data.startIndex + 7] == 0x70 { // p
            let brand = data[(data.startIndex + 8)...(data.startIndex + 11)]
            let brandString = String(bytes: brand, encoding: .ascii) ?? ""
            if brandString == "heic" || brandString == "heix" || brandString == "mif1" {
                self = .heic
                return
            }
        }

        return nil
    }
}

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

    /// Create a JSON response from raw `Data`.
    ///
    /// The data is sent as-is — no validation is performed.
    /// Sets `Content-Type: application/json; charset=utf-8` automatically.
    ///
    /// ```swift
    /// let jsonData = try JSONSerialization.data(withJSONObject: ["key": "value"])
    /// await server.stub(.GET, "/api/config", response: .json(jsonData))
    /// ```
    ///
    /// - Parameters:
    ///   - data: The raw JSON data.
    ///   - status: HTTP status code. Defaults to `.ok`.
    /// - Returns: A response with the JSON data as body.
    public static func json(
        _ data: Data,
        status: HTTPStatus = .ok
    ) -> MockHTTPResponse {
        MockHTTPResponse(
            status: status,
            headers: ["Content-Type": "application/json; charset=utf-8"],
            body: data
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

    /// Create an image response from raw `Data`.
    ///
    /// Sets the `Content-Type` header based on the provided ``ImageContentType``.
    /// When `contentType` is `nil` (the default), the format is auto-detected from
    /// the data's magic bytes, falling back to `.png` if detection fails.
    ///
    /// ```swift
    /// let pngData = try Data(contentsOf: pngURL)
    /// await server.stub(.GET, "/avatar.png",
    ///     response: .image(pngData, contentType: .png))
    /// ```
    ///
    /// - Parameters:
    ///   - data: The raw image data.
    ///   - contentType: The image MIME type. When `nil`, auto-detected from magic bytes
    ///     with a `.png` fallback.
    ///   - status: HTTP status code. Defaults to `.ok`.
    /// - Returns: A response with the image data and content type header.
    public static func image(
        _ data: Data,
        contentType: ImageContentType? = nil,
        status: HTTPStatus = .ok
    ) -> MockHTTPResponse {
        let resolved = contentType ?? ImageContentType(detecting: data) ?? .png
        return MockHTTPResponse(
            status: status,
            headers: ["Content-Type": resolved.rawValue],
            body: data
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
