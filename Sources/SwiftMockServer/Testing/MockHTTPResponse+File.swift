// MockHTTPResponse+File.swift
// SwiftMockServer

import Foundation

extension MockHTTPResponse {

    /// Create a JSON response from a file in a bundle.
    ///
    /// Loads the file contents and returns them with `Content-Type: application/json`.
    /// Returns `nil` if the file is not found.
    ///
    /// ```swift
    /// // Load "users.json" from the test bundle's resources
    /// await server.stub(.GET, "/api/users",
    ///     response: .jsonFile(named: "users.json", in: .module)!)
    /// ```
    ///
    /// - Parameters:
    ///   - filename: The file name (e.g., `"users.json"`). If no extension is provided, `.json` is assumed.
    ///   - bundle: The bundle containing the file. Use `.module` for SPM resources.
    ///   - status: HTTP status code. Defaults to `.ok`.
    /// - Returns: A response with the file contents as JSON body, or `nil` if the file was not found.
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

    /// Create an image response from a file in a bundle.
    ///
    /// The `Content-Type` header is inferred from the file extension.
    /// Returns `nil` if the file is not found.
    ///
    /// **Supported formats:** `png`, `jpg`/`jpeg`, `gif`, `webp`, `svg`, `heic`, `tiff`/`tif`, `bmp`, `ico`.
    ///
    /// ```swift
    /// // Load "avatar.png" from the test bundle's resources
    /// await server.stub(.GET, "/avatar.png",
    ///     response: .imageFile(named: "avatar.png", in: .module)!)
    /// ```
    ///
    /// - Parameters:
    ///   - filename: The image file name (e.g., `"avatar.png"`). If no extension is provided, `.png` is assumed.
    ///   - bundle: The bundle containing the file. Use `.module` for SPM resources.
    ///   - status: HTTP status code. Defaults to `.ok`.
    /// - Returns: A response with the image data and appropriate content type, or `nil` if not found.
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
