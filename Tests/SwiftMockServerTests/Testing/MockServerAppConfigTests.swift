// MockServerAppConfigTests.swift
// SwiftMockServerTests

import Testing
import Foundation
@testable import SwiftMockServer

@Suite("App Config")
struct AppConfigTests {

    @Test("Generates correct launch configuration")
    func appConfig() async throws {
        let server = try await MockServer.create()
        let config = await server.appConfig()

        #expect(config.launchArguments.contains("-useMockServer"))
        #expect(config.launchEnvironment["MOCK_SERVER_URL"]?.hasPrefix("http://127.0.0.1:") == true)
        #expect(config.launchEnvironment["MOCK_SERVER_PORT"] != nil)
        #expect(config.port > 0)

        await server.stop()
    }

    @Test("Includes additional environment in config")
    func additionalEnvironment() {
        let config = MockServerAppConfig(
            baseURL: "http://localhost:9999",
            port: 9999,
            additionalEnvironment: ["CUSTOM_KEY": "custom_value", "ANOTHER": "123"]
        )

        #expect(config.launchEnvironment["CUSTOM_KEY"] == "custom_value")
        #expect(config.launchEnvironment["ANOTHER"] == "123")
        #expect(config.launchEnvironment["MOCK_SERVER_URL"] == "http://localhost:9999")
    }
}
