// MockHTTPRequestTests.swift
// SwiftMockServerTests

import Testing
import Foundation
@testable import SwiftMockServer

@Suite("MockHTTPRequest")
struct MockHTTPRequestTests {

    @Test("jsonBody decodes valid JSON")
    func jsonBodyDecodes() throws {
        let json = Data("{\"name\":\"Alice\",\"age\":30}".utf8)
        let request = MockHTTPRequest(method: .POST, path: "/test", body: json)

        struct User: Decodable, Sendable { let name: String; let age: Int }
        let user = try request.jsonBody(User.self)

        #expect(user.name == "Alice")
        #expect(user.age == 30)
    }

    @Test("jsonBody throws when body is nil")
    func jsonBodyThrowsNoBody() {
        let request = MockHTTPRequest(method: .POST, path: "/test")

        #expect(throws: MockServerError.self) {
            struct Dummy: Decodable, Sendable {}
            _ = try request.jsonBody(Dummy.self)
        }
    }
}
