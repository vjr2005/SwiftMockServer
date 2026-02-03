// MockHTTPResponse+File.swift
// SwiftMockServer

import Foundation

extension MockHTTPResponse {

    /// Create a JSON response from a file in the test bundle.
    /// Useful for loading fixture files.
    public static func jsonFile(
        named filename: String,
        in bundle: Bundle,
        status: HTTPStatus = .ok
    ) -> MockHTTPResponse? {
        let name: String
        let ext: String
        if filename.contains(".") {
            let parts = filename.split(separator: ".", maxSplits: 1)
            name = String(parts[0])
            ext = String(parts[1])
        } else {
            name = filename
            ext = "json"
        }

        guard let url = bundle.url(forResource: name, withExtension: ext),
              let data = try? Data(contentsOf: url) else {
            return nil
        }

        return MockHTTPResponse(
            status: status,
            headers: ["Content-Type": "application/json; charset=utf-8"],
            body: data
        )
    }

    /// Create an image response from a file in the test bundle.
    ///
    /// The content type is inferred from the file extension.
    /// Supported formats: `png`, `jpg`/`jpeg`, `gif`, `webp`, `svg`, `heic`, `tiff`, `bmp`, `ico`.
    ///
    /// ```swift
    /// await server.stub(.GET, "/avatar.png",
    ///     response: .imageFile(named: "avatar.png", in: .module)!)
    /// ```
    public static func imageFile(
        named filename: String,
        in bundle: Bundle,
        status: HTTPStatus = .ok
    ) -> MockHTTPResponse? {
        let name: String
        let ext: String
        if filename.contains(".") {
            let parts = filename.split(separator: ".", maxSplits: 1)
            name = String(parts[0])
            ext = String(parts[1])
        } else {
            name = filename
            ext = "png"
        }

        guard let url = bundle.url(forResource: name, withExtension: ext),
              let data = try? Data(contentsOf: url) else {
            return nil
        }

        let contentType = imageContentType(for: ext)

        return MockHTTPResponse(
            status: status,
            headers: ["Content-Type": contentType],
            body: data
        )
    }

    private static func imageContentType(for ext: String) -> String {
        switch ext.lowercased() {
        case "png":             return "image/png"
        case "jpg", "jpeg":     return "image/jpeg"
        case "gif":             return "image/gif"
        case "webp":            return "image/webp"
        case "svg":             return "image/svg+xml"
        case "heic":            return "image/heic"
        case "tiff", "tif":     return "image/tiff"
        case "bmp":             return "image/bmp"
        case "ico":             return "image/x-icon"
        default:                return "application/octet-stream"
        }
    }
}
