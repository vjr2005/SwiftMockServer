// MockHTTPResponseTests.swift
// SwiftMockServerTests

import Testing
import Foundation
@testable import SwiftMockServer

@Suite("MockHTTPResponse")
struct MockHTTPResponseTests {

    @Test("json creates correct response")
    func jsonResponse() {
        let response = MockHTTPResponse.json("{\"ok\":true}")
        #expect(response.status == .ok)
        #expect(response.headers["Content-Type"] == "application/json; charset=utf-8")
        #expect(response.bodyString == "{\"ok\":true}")
    }

    @Test("text creates correct response")
    func textResponse() {
        let response = MockHTTPResponse.text("hello")
        #expect(response.headers["Content-Type"] == "text/plain; charset=utf-8")
    }

    @Test("json encodes Encodable value")
    func jsonEncodableResponse() throws {
        struct Item: Encodable, Sendable { let id: Int; let name: String }
        let response = try MockHTTPResponse.json(Item(id: 1, name: "Test"))

        #expect(response.status == .ok)
        #expect(response.headers["Content-Type"] == "application/json; charset=utf-8")
        #expect(response.body != nil)
    }

    @Test("html creates correct response")
    func htmlResponse() {
        let response = MockHTTPResponse.html("<h1>Hello</h1>")
        #expect(response.status == .ok)
        #expect(response.headers["Content-Type"] == "text/html; charset=utf-8")
        #expect(response.body == Data("<h1>Hello</h1>".utf8))
    }

    @Test("data creates correct response")
    func dataResponse() {
        let bytes = Data([0x00, 0x01, 0x02])
        let response = MockHTTPResponse.data(bytes, contentType: "application/octet-stream")

        #expect(response.status == .ok)
        #expect(response.headers["Content-Type"] == "application/octet-stream")
        #expect(response.body == bytes)
    }

    @Test("json(Data) sets correct content type and body")
    func jsonDataResponse() {
        let jsonData = Data(#"{"key":"value"}"#.utf8)
        let response = MockHTTPResponse.json(jsonData)

        #expect(response.status == .ok)
        #expect(response.headers["Content-Type"] == "application/json; charset=utf-8")
        #expect(response.body == jsonData)
    }

    @Test("image(Data) auto-detects PNG from magic bytes")
    func imageDataDefaultsPNG() {
        let imageData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let response = MockHTTPResponse.image(imageData)

        #expect(response.status == .ok)
        #expect(response.headers["Content-Type"] == "image/png")
        #expect(response.body == imageData)
    }

    @Test("image(Data) falls back to image/png for unknown data")
    func imageDataFallbackPNG() {
        let imageData = Data([0x01, 0x02, 0x03, 0x04])
        let response = MockHTTPResponse.image(imageData)

        #expect(response.status == .ok)
        #expect(response.headers["Content-Type"] == "image/png")
    }

    @Test("image(Data, contentType: .jpeg) uses image/jpeg")
    func imageDataJPEG() {
        let imageData = Data([0xFF, 0xD8, 0xFF])
        let response = MockHTTPResponse.image(imageData, contentType: .jpeg)

        #expect(response.status == .ok)
        #expect(response.headers["Content-Type"] == "image/jpeg")
        #expect(response.body == imageData)
    }

    // MARK: - ImageContentType(detecting:) tests

    @Test("detects PNG from magic bytes")
    func detectPNG() {
        let data = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        #expect(ImageContentType(detecting: data) == .png)
    }

    @Test("detects JPEG from magic bytes")
    func detectJPEG() {
        let data = Data([0xFF, 0xD8, 0xFF, 0xE0])
        #expect(ImageContentType(detecting: data) == .jpeg)
    }

    @Test("detects GIF from magic bytes")
    func detectGIF() {
        let data = Data([0x47, 0x49, 0x46, 0x38, 0x39, 0x61])
        #expect(ImageContentType(detecting: data) == .gif)
    }

    @Test("detects WebP from magic bytes")
    func detectWebP() {
        // RIFF????WEBP
        let data = Data([0x52, 0x49, 0x46, 0x46,
                         0x00, 0x00, 0x00, 0x00,
                         0x57, 0x45, 0x42, 0x50])
        #expect(ImageContentType(detecting: data) == .webp)
    }

    @Test("detects BMP from magic bytes")
    func detectBMP() {
        let data = Data([0x42, 0x4D, 0x00, 0x00])
        #expect(ImageContentType(detecting: data) == .bmp)
    }

    @Test("detects TIFF little-endian from magic bytes")
    func detectTIFFLE() {
        let data = Data([0x49, 0x49, 0x2A, 0x00])
        #expect(ImageContentType(detecting: data) == .tiff)
    }

    @Test("detects TIFF big-endian from magic bytes")
    func detectTIFFBE() {
        let data = Data([0x4D, 0x4D, 0x00, 0x2A])
        #expect(ImageContentType(detecting: data) == .tiff)
    }

    @Test("detects ICO from magic bytes")
    func detectICO() {
        let data = Data([0x00, 0x00, 0x01, 0x00])
        #expect(ImageContentType(detecting: data) == .ico)
    }

    @Test("detects HEIC from magic bytes")
    func detectHEIC() {
        // size(4) + ftyp + heic
        let data = Data([0x00, 0x00, 0x00, 0x18,
                         0x66, 0x74, 0x79, 0x70,
                         0x68, 0x65, 0x69, 0x63])
        #expect(ImageContentType(detecting: data) == .heic)
    }

    @Test("detects HEIC with mif1 brand")
    func detectHEICMif1() {
        let data = Data([0x00, 0x00, 0x00, 0x1C,
                         0x66, 0x74, 0x79, 0x70,
                         0x6D, 0x69, 0x66, 0x31]) // mif1
        #expect(ImageContentType(detecting: data) == .heic)
    }

    @Test("returns nil for empty data")
    func detectEmpty() {
        #expect(ImageContentType(detecting: Data()) == nil)
    }

    @Test("returns nil for unrecognized data")
    func detectUnknown() {
        let data = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
                         0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10])
        #expect(ImageContentType(detecting: data) == nil)
    }
}
