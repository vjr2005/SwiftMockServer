// TestHelpers.swift
// SwiftMockServerTests

@testable import SwiftMockServer

extension MockHTTPResponse {
    var bodyString: String? {
        body.flatMap { String(data: $0, encoding: .utf8) }
    }
}
