// MockServerDetectorTests.swift
// SwiftMockServerTests

import Testing
@testable import SwiftMockServer

@Suite("MockServerDetector")
struct MockServerDetectorTests {

    @Test("detects mock server flag in arguments")
    func detectsFlag() {
        #expect(MockServerDetector.isUsingMockServer(arguments: ["-useMockServer"]))
        #expect(MockServerDetector.isUsingMockServer(arguments: ["other", "-useMockServer", "more"]))
    }

    @Test("returns false when flag is absent")
    func noFlag() {
        #expect(!MockServerDetector.isUsingMockServer(arguments: []))
        #expect(!MockServerDetector.isUsingMockServer(arguments: ["--other"]))
    }

    @Test("supports custom flag")
    func customFlag() {
        #expect(MockServerDetector.isUsingMockServer(arguments: ["--mock"], flag: "--mock"))
        #expect(!MockServerDetector.isUsingMockServer(arguments: ["-useMockServer"], flag: "--mock"))
    }

    @Test("extracts base URL from environment")
    func extractsBaseURL() {
        let env = ["MOCK_SERVER_URL": "http://localhost:9999"]
        #expect(MockServerDetector.baseURL(from: env) == "http://localhost:9999")
    }

    @Test("returns nil when base URL key is missing")
    func missingBaseURL() {
        #expect(MockServerDetector.baseURL(from: [:]) == nil)
    }

    @Test("supports custom base URL key")
    func customBaseURLKey() {
        let env = ["API_URL": "http://localhost:1234"]
        #expect(MockServerDetector.baseURL(from: env, key: "API_URL") == "http://localhost:1234")
    }

    @Test("extracts port from environment")
    func extractsPort() {
        let env = ["MOCK_SERVER_PORT": "8080"]
        #expect(MockServerDetector.port(from: env) == 8080)
    }

    @Test("returns nil for missing or invalid port")
    func invalidPort() {
        #expect(MockServerDetector.port(from: [:]) == nil)
        #expect(MockServerDetector.port(from: ["MOCK_SERVER_PORT": "abc"]) == nil)
        #expect(MockServerDetector.port(from: ["MOCK_SERVER_PORT": "-1"]) == nil)
        #expect(MockServerDetector.port(from: ["MOCK_SERVER_PORT": "99999"]) == nil)
    }

    @Test("supports custom port key")
    func customPortKey() {
        let env = ["MY_PORT": "3000"]
        #expect(MockServerDetector.port(from: env, key: "MY_PORT") == 3000)
    }

    @Test("static properties read from ProcessInfo")
    func staticProperties() {
        // The test process is not launched with -useMockServer
        #expect(!MockServerDetector.isUsingMockServer)
        // The test process has no MOCK_SERVER_URL or MOCK_SERVER_PORT
        #expect(MockServerDetector.baseURL == nil)
        #expect(MockServerDetector.port == nil)
    }
}
