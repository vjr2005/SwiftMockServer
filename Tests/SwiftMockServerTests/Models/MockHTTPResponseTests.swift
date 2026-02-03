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
}
