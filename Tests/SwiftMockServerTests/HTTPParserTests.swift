// HTTPParserTests.swift
// SwiftMockServerTests

import Testing
import Foundation
@testable import SwiftMockServer

@Suite("HTTP Parser")
struct HTTPParserTests {

    @Test("Parses a simple GET request")
    func parseSimpleGET() throws {
        let raw = "GET /api/users HTTP/1.1\r\nHost: localhost\r\nAccept: application/json\r\n\r\n"
        let request = try HTTPParser.parse(Data(raw.utf8))

        #expect(request.method == .GET)
        #expect(request.path == "/api/users")
        #expect(request.headers["Host"] == "localhost")
        #expect(request.headers["Accept"] == "application/json")
        #expect(request.body == nil)
    }

    @Test("Parses GET with query parameters")
    func parseGETWithQuery() throws {
        let raw = "GET /search?q=swift&page=2 HTTP/1.1\r\nHost: localhost\r\n\r\n"
        let request = try HTTPParser.parse(Data(raw.utf8))

        #expect(request.path == "/search")
        #expect(request.queryParameters["q"] == "swift")
        #expect(request.queryParameters["page"] == "2")
    }

    @Test("Parses POST with JSON body")
    func parsePOSTWithBody() throws {
        let body = "{\"name\":\"Alice\",\"age\":30}"
        let raw = "POST /api/users HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\n\r\n\(body)"
        let request = try HTTPParser.parse(Data(raw.utf8))

        #expect(request.method == .POST)
        #expect(request.path == "/api/users")
        #expect(request.bodyString == body)
    }

    @Test("Throws for non-UTF8 data")
    func throwsForNonUTF8() {
        // 0xFE 0xFF alone are not valid UTF-8
        let data = Data([0xFE, 0xFF, 0x80, 0x81])
        #expect(throws: MockServerError.self) {
            _ = try HTTPParser.parse(data)
        }
    }

    @Test("Throws for empty request")
    func throwsForEmptyRequest() {
        let data = Data("\r\n\r\n".utf8)
        #expect(throws: MockServerError.self) {
            _ = try HTTPParser.parse(data)
        }
    }

    @Test("Throws for missing request line")
    func throwsForMissingRequestLine() {
        let data = Data("".utf8)
        #expect(throws: MockServerError.self) {
            _ = try HTTPParser.parse(data)
        }
    }

    @Test("Throws for malformed request line")
    func throwsForMalformedRequestLine() {
        let data = Data("INVALID\r\n\r\n".utf8)
        #expect(throws: MockServerError.self) {
            _ = try HTTPParser.parse(data)
        }
    }

    @Test("Throws for unknown HTTP method")
    func throwsForUnknownMethod() {
        let data = Data("BOGUS /path HTTP/1.1\r\n\r\n".utf8)
        #expect(throws: MockServerError.self) {
            _ = try HTTPParser.parse(data)
        }
    }

    @Test("Parses percent-encoded query parameters")
    func parsesPercentEncodedQuery() throws {
        let raw = "GET /search?q=hello%20world&tag=swift%26ios HTTP/1.1\r\nHost: localhost\r\n\r\n"
        let request = try HTTPParser.parse(Data(raw.utf8))

        #expect(request.queryParameters["q"] == "hello world")
        #expect(request.queryParameters["tag"] == "swift&ios")
    }

    @Test("Parses query parameter without value")
    func parsesQueryParamWithoutValue() throws {
        let raw = "GET /search?flag&key=val HTTP/1.1\r\nHost: localhost\r\n\r\n"
        let request = try HTTPParser.parse(Data(raw.utf8))

        #expect(request.queryParameters["flag"] == "")
        #expect(request.queryParameters["key"] == "val")
    }

    @Test("Serializes response correctly")
    func serializeResponse() throws {
        let response = MockHTTPResponse.json("{\"ok\":true}")
        let data = HTTPParser.serialize(response)
        let string = String(data: data, encoding: .utf8)!

        #expect(string.contains("HTTP/1.1 200 OK"))
        #expect(string.contains("Content-Type: application/json"))
        #expect(string.contains("{\"ok\":true}"))
    }
}
