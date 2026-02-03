// MockHTTPResponseFileTests.swift
// SwiftMockServerTests

import Testing
import Foundation
@testable import SwiftMockServer

// MARK: - Image File Tests

@Suite("Image File Helper")
struct ImageFileTests {

    /// Minimal valid 1x1 white PNG (67 bytes).
    private static let minimalPNG: Data = {
        let bytes: [UInt8] = [
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1
            0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, // 8-bit RGB
            0xDE,
            0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, // IDAT chunk
            0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00, 0x00,
            0x00, 0x02, 0x00, 0x01, 0xE2, 0x21, 0xBC, 0x33,
            0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, // IEND chunk
            0xAE, 0x42, 0x60, 0x82,
        ]
        return Data(bytes)
    }()

    /// Create a temporary .bundle directory containing a fixture image file.
    private func makeTempBundle(filename: String, data: Data) throws -> Bundle {
        let bundleDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".bundle")
        try FileManager.default.createDirectory(at: bundleDir, withIntermediateDirectories: true)
        try data.write(to: bundleDir.appendingPathComponent(filename))
        return Bundle(url: bundleDir)!
    }

    @Test("imageFile loads PNG with correct content type")
    func loadsPNG() throws {
        let bundle = try makeTempBundle(filename: "avatar.png", data: Self.minimalPNG)
        let response = MockHTTPResponse.imageFile(named: "avatar.png", in: bundle)

        #expect(response != nil)
        #expect(response?.status == .ok)
        #expect(response?.headers["Content-Type"] == "image/png")
        #expect(response?.body == Self.minimalPNG)
    }

    @Test("imageFile infers JPEG content type")
    func infersJPEGContentType() throws {
        let bundle = try makeTempBundle(filename: "photo.jpg", data: Self.minimalPNG)
        let response = MockHTTPResponse.imageFile(named: "photo.jpg", in: bundle)

        #expect(response?.headers["Content-Type"] == "image/jpeg")
    }

    @Test("imageFile defaults to PNG when no extension given")
    func defaultsToPNG() throws {
        let bundle = try makeTempBundle(filename: "icon.png", data: Self.minimalPNG)
        let response = MockHTTPResponse.imageFile(named: "icon", in: bundle)

        #expect(response != nil)
        #expect(response?.headers["Content-Type"] == "image/png")
    }

    @Test("imageFile returns nil for missing file")
    func returnsNilForMissing() throws {
        let bundle = try makeTempBundle(filename: "exists.png", data: Self.minimalPNG)
        let response = MockHTTPResponse.imageFile(named: "nope.png", in: bundle)

        #expect(response == nil)
    }

    @Test("imageFile respects custom status")
    func customStatus() throws {
        let bundle = try makeTempBundle(filename: "avatar.png", data: Self.minimalPNG)
        let response = MockHTTPResponse.imageFile(named: "avatar.png", in: bundle, status: .created)

        #expect(response?.status == .created)
    }

    @Test("imageFile serves image through MockServer")
    func servesImageThroughServer() async throws {
        let bundle = try makeTempBundle(filename: "avatar.png", data: Self.minimalPNG)
        let response = MockHTTPResponse.imageFile(named: "avatar.png", in: bundle)!

        let server = try await MockServer.create()
        let port = await server.port

        await server.stub(.GET, "/images/avatar.png", response: response)

        let url = URL(string: "http://[::1]:\(port)/images/avatar.png")!
        let (data, httpResponse) = try await makeSession().data(from: url)
        let status = (httpResponse as! HTTPURLResponse).statusCode

        #expect(status == 200)
        #expect(data == Self.minimalPNG)

        await server.stop()
    }

    @Test("stubImage registers image route from fixture")
    func stubImageRegistersRoute() async throws {
        let bundle = try makeTempBundle(filename: "logo.png", data: Self.minimalPNG)

        let server = try await MockServer.create()
        let port = await server.port

        try await server.stubImage(.GET, "/logo.png", named: "logo.png", in: bundle)

        let url = URL(string: "http://[::1]:\(port)/logo.png")!
        let (data, httpResponse) = try await makeSession().data(from: url)
        let status = (httpResponse as! HTTPURLResponse).statusCode

        #expect(status == 200)
        #expect(data == Self.minimalPNG)

        await server.stop()
    }

    @Test("stubImage throws for missing fixture")
    func stubImageThrowsForMissing() async throws {
        let bundle = try makeTempBundle(filename: "exists.png", data: Self.minimalPNG)
        let server = try await MockServer.create()

        await #expect(throws: MockServerError.self) {
            try await server.stubImage(.GET, "/nope.png", named: "nope.png", in: bundle)
        }

        await server.stop()
    }

    @Test("imageFile infers content type for all supported formats", arguments: [
        ("photo.jpeg", "image/jpeg"),
        ("anim.gif", "image/gif"),
        ("modern.webp", "image/webp"),
        ("vector.svg", "image/svg+xml"),
        ("apple.heic", "image/heic"),
        ("scan.tiff", "image/tiff"),
        ("scan.tif", "image/tiff"),
        ("legacy.bmp", "image/bmp"),
        ("favicon.ico", "image/x-icon"),
        ("unknown.xyz", "application/octet-stream"),
    ])
    func infersContentType(filename: String, expectedContentType: String) throws {
        let bundle = try makeTempBundle(filename: filename, data: Self.minimalPNG)
        let response = MockHTTPResponse.imageFile(named: filename, in: bundle)

        #expect(response != nil)
        #expect(response?.headers["Content-Type"] == expectedContentType)
    }
}

// MARK: - JSON File Tests

@Suite("JSON File Helper")
struct JSONFileTests {

    private static let sampleJSON = Data("""
    {"id": 1, "name": "Alice"}
    """.utf8)

    private func makeTempBundle(filename: String, data: Data) throws -> Bundle {
        let bundleDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".bundle")
        try FileManager.default.createDirectory(at: bundleDir, withIntermediateDirectories: true)
        try data.write(to: bundleDir.appendingPathComponent(filename))
        return Bundle(url: bundleDir)!
    }

    @Test("jsonFile loads file with extension")
    func loadsWithExtension() throws {
        let bundle = try makeTempBundle(filename: "users.json", data: Self.sampleJSON)
        let response = MockHTTPResponse.jsonFile(named: "users.json", in: bundle)

        #expect(response != nil)
        #expect(response?.status == .ok)
        #expect(response?.headers["Content-Type"] == "application/json; charset=utf-8")
        #expect(response?.body == Self.sampleJSON)
    }

    @Test("jsonFile defaults to .json extension when omitted")
    func defaultsToJSONExtension() throws {
        let bundle = try makeTempBundle(filename: "users.json", data: Self.sampleJSON)
        let response = MockHTTPResponse.jsonFile(named: "users", in: bundle)

        #expect(response != nil)
        #expect(response?.body == Self.sampleJSON)
    }

    @Test("jsonFile returns nil for missing file")
    func returnsNilForMissing() throws {
        let bundle = try makeTempBundle(filename: "exists.json", data: Self.sampleJSON)
        let response = MockHTTPResponse.jsonFile(named: "nope.json", in: bundle)

        #expect(response == nil)
    }

    @Test("jsonFile respects custom status")
    func customStatus() throws {
        let bundle = try makeTempBundle(filename: "created.json", data: Self.sampleJSON)
        let response = MockHTTPResponse.jsonFile(named: "created.json", in: bundle, status: .created)

        #expect(response?.status == .created)
    }
}
