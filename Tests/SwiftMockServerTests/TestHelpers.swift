// TestHelpers.swift
// SwiftMockServerTests

import Foundation
@testable import SwiftMockServer

extension MockHTTPResponse {
    var bodyString: String? {
        body.flatMap { String(data: $0, encoding: .utf8) }
    }
}

/// Ephemeral URLSession that does not cache connection state across tests.
func makeSession() -> URLSession {
    URLSession(configuration: .ephemeral)
}
