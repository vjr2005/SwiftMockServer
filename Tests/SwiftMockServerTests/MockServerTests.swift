// MockServerTests.swift
// SwiftMockServerTests

import Testing
import Foundation
@testable import SwiftMockServer

@Suite("MockServer Integration")
struct MockServerIntegrationTests {

    @Test("Server starts and returns port")
    func serverStartsAndReturnsPort() async throws {
        let server = MockServer()
        try await server.start()
        let port = await server.port

        #expect(port > 0)
        #expect(await server.isRunning)

        await server.stop()
        #expect(await server.isRunning == false)
    }

    @Test("Auto-assigned ports are unique across instances")
    func uniquePorts() async throws {
        let server1 = MockServer()
        let server2 = MockServer()
        let server3 = MockServer()

        try await server1.start()
        try await server2.start()
        try await server3.start()

        let port1 = await server1.port
        let port2 = await server2.port
        let port3 = await server3.port

        #expect(port1 != port2)
        #expect(port2 != port3)
        #expect(port1 != port3)

        await server1.stop()
        await server2.stop()
        await server3.stop()
    }

    @Test("Responds to HTTP requests via URLSession")
    func respondsToHTTPRequests() async throws {
        let server = try await MockServer.create()
        let port = await server.port

        await server.stubJSON(.GET, "/api/hello", json: """
        {"message": "Hello, World!"}
        """)

        let url = try #require(URL(string: "http://[::1]:\(port)/api/hello"))
        let (data, response) = try await makeSession().data(from: url)
        let httpResponse = try #require(response as? HTTPURLResponse)

        #expect(httpResponse.statusCode == 200)

        let body = try JSONDecoder().decode([String: String].self, from: data)
        #expect(body["message"] == "Hello, World!")

        await server.stop()
    }

    @Test("Returns 404 for unregistered routes")
    func returns404ForUnregisteredRoutes() async throws {
        let server = try await MockServer.create()
        let port = await server.port

        let url = try #require(URL(string: "http://[::1]:\(port)/nonexistent"))
        let (_, response) = try await makeSession().data(from: url)
        let httpResponse = try #require(response as? HTTPURLResponse)

        #expect(httpResponse.statusCode == 404)

        await server.stop()
    }

    @Test("Records incoming requests")
    func recordsRequests() async throws {
        let server = try await MockServer.create()
        let port = await server.port

        await server.stub(.GET, "/api/track", response: .status(.ok))

        let url = try #require(URL(string: "http://[::1]:\(port)/api/track"))
        _ = try await makeSession().data(from: url)

        // Give a moment for the request to be recorded
        try await Task.sleep(for: .milliseconds(100))

        let recorded = await server.requests(matching: "/api/track")
        #expect(recorded.count == 1)
        #expect(recorded.first?.request.method == .GET)

        #expect(await server.didReceive(method: .GET, path: "/api/track"))
        #expect(await server.didReceive(path: "/api/track"))

        await server.stop()
    }

    @Test("Supports overriding routes mid-test (LIFO)")
    func overridesRoutes() async throws {
        let server = try await MockServer.create()
        let port = await server.port
        let url = try #require(URL(string: "http://[::1]:\(port)/api/data"))

        let session = makeSession()

        // First stub
        await server.stubJSON(.GET, "/api/data", json: "{\"v\": 1}")

        let (data1, _) = try await session.data(from: url)
        let v1 = try JSONDecoder().decode([String: Int].self, from: data1)
        #expect(v1["v"] == 1)

        // Override with new stub
        await server.stubJSON(.GET, "/api/data", json: "{\"v\": 2}")

        let (data2, _) = try await session.data(from: url)
        let v2 = try JSONDecoder().decode([String: Int].self, from: data2)
        #expect(v2["v"] == 2)

        await server.stop()
    }

    @Test("Parallel servers don't interfere with each other")
    func parallelServersIsolated() async throws {
        // Simulate parallel testing: multiple servers running simultaneously
        let servers = try await withThrowingTaskGroup(of: (MockServer, UInt16, Int).self) { group in
            for i in 0..<5 {
                group.addTask {
                    let server = try await MockServer.create()
                    await server.stubJSON(.GET, "/api/id", json: "{\"id\": \(i)}")
                    let port = await server.port
                    return (server, port, i)
                }
            }

            var results: [(MockServer, UInt16, Int)] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }

        // Verify each server responds with its own data
        for (_, port, expectedID) in servers {
            let url = try #require(URL(string: "http://[::1]:\(port)/api/id"))
            let (data, response) = try await makeSession().data(from: url)
            let httpResponse = try #require(response as? HTTPURLResponse)
            #expect(httpResponse.statusCode == 200)

            let body = try JSONDecoder().decode([String: Int].self, from: data)
            #expect(body["id"] == expectedID)
        }

        // Clean up
        for (server, _, _) in servers {
            await server.stop()
        }
    }

    @Test("Port returns requestedPort before start")
    func portBeforeStart() async {
        let server = MockServer(port: 9999)
        let port = await server.port

        #expect(port == 9999)
    }

    @Test("Requests property returns all recorded requests")
    func requestsProperty() async throws {
        let server = try await MockServer.create()
        let port = await server.port

        await server.stub(.GET, "/a", response: .status(.ok))
        await server.stub(.POST, "/b", response: .status(.ok))

        let urlA = try #require(URL(string: "http://[::1]:\(port)/a"))
        let urlB = try #require(URL(string: "http://[::1]:\(port)/b"))
        let session = makeSession()
        _ = try await session.data(from: urlA)
        _ = try await session.data(from: urlB)

        _ = try await server.waitForRequest(path: "/b", timeout: .seconds(2))

        let all = await server.requests
        #expect(all.count == 2)

        await server.stop()
    }

    @Test("Throws alreadyRunning when started twice")
    func throwsAlreadyRunning() async throws {
        let server = try await MockServer.create()

        await #expect(throws: MockServerError.self) {
            try await server.start()
        }

        await server.stop()
    }

    @Test("registerParameterized returns route ID")
    func registerParameterizedReturnsId() async throws {
        let server = try await MockServer.create()
        let port = await server.port

        let id = await server.registerParameterized(.GET, "/items/:id") { _ in .status(.ok) }
        #expect(!id.isEmpty)

        let url = try #require(URL(string: "http://[::1]:\(port)/items/42"))
        let (_, response) = try await makeSession().data(from: url)
        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 200)

        await server.stop()
    }

    @Test("registerPrefix returns route ID and matches")
    func registerPrefixReturnsId() async throws {
        let server = try await MockServer.create()
        let port = await server.port

        let id = await server.registerPrefix(.GET, "/static/") { _ in .text("file") }
        #expect(!id.isEmpty)

        let url = try #require(URL(string: "http://[::1]:\(port)/static/image.png"))
        let (data, _) = try await makeSession().data(from: url)
        #expect(String(data: data, encoding: .utf8) == "file")

        await server.stop()
    }

    @Test("registerCatchAll catches unmatched routes")
    func registerCatchAllWorks() async throws {
        let server = try await MockServer.create()
        let port = await server.port

        let id = await server.registerCatchAll { _ in .text("caught") }
        #expect(!id.isEmpty)

        let url = try #require(URL(string: "http://[::1]:\(port)/any/path/here"))
        let (data, _) = try await makeSession().data(from: url)
        #expect(String(data: data, encoding: .utf8) == "caught")

        await server.stop()
    }

    @Test("removeRoute removes a specific route")
    func removeRouteById() async throws {
        let server = try await MockServer.create()
        let port = await server.port

        let id = await server.stub(.GET, "/temp", response: .text("exists"))

        let url = try #require(URL(string: "http://[::1]:\(port)/temp"))
        let session = makeSession()
        let (data1, _) = try await session.data(from: url)
        #expect(String(data: data1, encoding: .utf8) == "exists")

        await server.removeRoute(id: id)

        let (_, response2) = try await session.data(from: url)
        let httpResponse2 = try #require(response2 as? HTTPURLResponse)
        #expect(httpResponse2.statusCode == 404)

        await server.stop()
    }

    @Test("removeAllRoutes clears all routes")
    func removeAllRoutesWorks() async throws {
        let server = try await MockServer.create()
        let port = await server.port

        await server.stub(.GET, "/a", response: .status(.ok))
        await server.stub(.GET, "/b", response: .status(.ok))
        await server.removeAllRoutes()

        let url = try #require(URL(string: "http://[::1]:\(port)/a"))
        let (_, response) = try await makeSession().data(from: url)
        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 404)

        await server.stop()
    }

    @Test("setDefaultResponse changes unmatched response")
    func setDefaultResponseWorks() async throws {
        let server = try await MockServer.create()
        let port = await server.port

        await server.setDefaultResponse(.text("custom fallback", status: .badRequest))

        let url = try #require(URL(string: "http://[::1]:\(port)/unmatched"))
        let (data, response) = try await makeSession().data(from: url)
        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 400)
        #expect(String(data: data, encoding: .utf8) == "custom fallback")

        await server.stop()
    }

    @Test("setResponseDelay is accepted")
    func setResponseDelayWorks() async throws {
        let server = try await MockServer.create()

        await server.setResponseDelay(.milliseconds(10))
        await server.setResponseDelay(nil)

        await server.stop()
    }

    @Test("clearRecordedRequests empties the log")
    func clearRecordedRequestsWorks() async throws {
        let server = try await MockServer.create()
        let port = await server.port

        await server.stub(.GET, "/log", response: .status(.ok))
        let url = try #require(URL(string: "http://[::1]:\(port)/log"))
        _ = try await makeSession().data(from: url)

        _ = try await server.waitForRequest(path: "/log", timeout: .seconds(2))
        #expect(await server.requests(matching: "/log").count == 1)

        await server.clearRecordedRequests()
        #expect(await server.requests(matching: "/log").count == 0)

        await server.stop()
    }

    @Test("requests(method:path:) filters by method and path")
    func requestsFilteredByMethodAndPath() async throws {
        let server = try await MockServer.create()
        let port = await server.port

        await server.stub(.GET, "/filter", response: .status(.ok))
        await server.stub(.POST, "/filter", response: .status(.ok))

        let getURL = try #require(URL(string: "http://[::1]:\(port)/filter"))
        let session = makeSession()
        _ = try await session.data(from: getURL)

        var postRequest = URLRequest(url: getURL)
        postRequest.httpMethod = "POST"
        _ = try await session.data(for: postRequest)

        _ = try await server.waitForRequest(method: .POST, path: "/filter", timeout: .seconds(2))

        let getOnly = await server.requests(method: .GET, path: "/filter")
        let postOnly = await server.requests(method: .POST, path: "/filter")

        #expect(getOnly.count == 1)
        #expect(postOnly.count == 1)

        await server.stop()
    }

    @Test("waitForRequest returns matching request")
    func waitForRequestWorks() async throws {
        let server = try await MockServer.create()
        let port = await server.port

        await server.stub(.GET, "/wait", response: .status(.ok))

        let session = makeSession()
        Task {
            try await Task.sleep(for: .milliseconds(100))
            let url = try #require(URL(string: "http://[::1]:\(port)/wait"))
            _ = try await session.data(from: url)
        }

        let recorded = try await server.waitForRequest(path: "/wait", timeout: .seconds(2))
        #expect(recorded.request.path == "/wait")

        await server.stop()
    }

    @Test("Handler error returns 500 with error message")
    func handlerErrorReturns500() async throws {
        let server = try await MockServer.create()
        let port = await server.port

        await server.register(.GET, "/fail") { _ in
            throw MockServerError.invalidRequest("test error")
        }

        let url = try #require(URL(string: "http://[::1]:\(port)/fail"))
        let (data, response) = try await makeSession().data(from: url)
        let httpResponse = try #require(response as? HTTPURLResponse)

        #expect(httpResponse.statusCode == 500)
        #expect(String(data: data, encoding: .utf8)?.contains("test error") == true)

        await server.stop()
    }

    @Test("startAndGetURL returns base URL")
    func startAndGetURLWorks() async throws {
        let server = MockServer()
        let url = try await server.startAndGetURL()

        #expect(url.hasPrefix("http://[::1]:"))

        await server.stop()
    }
}
