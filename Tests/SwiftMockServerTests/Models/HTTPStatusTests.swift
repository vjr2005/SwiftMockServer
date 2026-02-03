// HTTPStatusTests.swift
// SwiftMockServerTests

import Testing
@testable import SwiftMockServer

@Suite("HTTPStatus")
struct HTTPStatusTests {

    @Test("HTTPStatus equality")
    func statusEquality() {
        #expect(HTTPStatus.ok == HTTPStatus(code: 200, reason: "OK"))
        #expect(HTTPStatus.notFound != HTTPStatus.ok)
    }

    @Test("HTTPStatus description")
    func statusDescription() {
        #expect(HTTPStatus.ok.description == "200 OK")
        #expect(HTTPStatus.notFound.description == "404 Not Found")
    }
}
