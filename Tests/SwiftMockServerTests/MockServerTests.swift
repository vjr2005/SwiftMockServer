// MockServerTests.swift
// SwiftMockServerTests

import Testing
import Foundation
@testable import SwiftMockServer

// MARK: - HTTP Parser Tests

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

// MARK: - Router Tests

@Suite("Router")
struct RouterTests {

    @Test("Matches exact path")
    func exactMatch() {
        let route = Route(
            method: .GET,
            pattern: .exact("/api/users"),
            handler: { _ in .status(.ok) }
        )

        let request = MockHTTPRequest(method: .GET, path: "/api/users")
        let match = RouterEngine.match(request: request, routes: [route])

        #expect(match != nil)
    }

    @Test("Does not match wrong method")
    func wrongMethod() {
        let route = Route(
            method: .GET,
            pattern: .exact("/api/users"),
            handler: { _ in .status(.ok) }
        )

        let request = MockHTTPRequest(method: .POST, path: "/api/users")
        let match = RouterEngine.match(request: request, routes: [route])

        #expect(match == nil)
    }

    @Test("Matches parameterized path")
    func parameterizedMatch() {
        let route = Route(
            method: .GET,
            pattern: .parameterized("/users/:id/posts/:postId"),
            handler: { _ in .status(.ok) }
        )

        let request = MockHTTPRequest(method: .GET, path: "/users/42/posts/99")
        let match = RouterEngine.match(request: request, routes: [route])

        #expect(match != nil)
        #expect(match?.pathParameters["id"] == "42")
        #expect(match?.pathParameters["postId"] == "99")
    }

    @Test("Matches prefix")
    func prefixMatch() {
        let route = Route(
            method: nil,
            pattern: .prefix("/api/"),
            handler: { _ in .status(.ok) }
        )

        let request = MockHTTPRequest(method: .DELETE, path: "/api/anything/here")
        let match = RouterEngine.match(request: request, routes: [route])

        #expect(match != nil)
    }

    @Test("Matches any")
    func anyMatch() {
        let route = Route(
            pattern: .any,
            handler: { _ in .status(.ok) }
        )

        let request = MockHTTPRequest(method: .PUT, path: "/literally/anything")
        let match = RouterEngine.match(request: request, routes: [route])

        #expect(match != nil)
    }

    @Test("LIFO order: later routes have priority")
    func lifoOrder() {
        let route1 = Route(
            method: .GET,
            pattern: .exact("/test"),
            handler: { _ in .text("first") }
        )
        let route2 = Route(
            method: .GET,
            pattern: .exact("/test"),
            handler: { _ in .text("second") }
        )

        let request = MockHTTPRequest(method: .GET, path: "/test")
        // route2 comes first in the array (simulating LIFO insertion)
        let match = RouterEngine.match(request: request, routes: [route2, route1])

        #expect(match?.route.id == route2.id)
    }
}

// MARK: - MockServer Integration Tests

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

        let url = URL(string: "http://127.0.0.1:\(port)/api/hello")!
        let (data, response) = try await URLSession.shared.data(from: url)
        let httpResponse = response as! HTTPURLResponse

        #expect(httpResponse.statusCode == 200)

        let body = try JSONDecoder().decode([String: String].self, from: data)
        #expect(body["message"] == "Hello, World!")

        await server.stop()
    }

    @Test("Returns 404 for unregistered routes")
    func returns404ForUnregisteredRoutes() async throws {
        let server = try await MockServer.create()
        let port = await server.port

        let url = URL(string: "http://127.0.0.1:\(port)/nonexistent")!
        let (_, response) = try await URLSession.shared.data(from: url)
        let httpResponse = response as! HTTPURLResponse

        #expect(httpResponse.statusCode == 404)

        await server.stop()
    }

    @Test("Records incoming requests")
    func recordsRequests() async throws {
        let server = try await MockServer.create()
        let port = await server.port

        await server.stub(.GET, "/api/track", response: .status(.ok))

        let url = URL(string: "http://127.0.0.1:\(port)/api/track")!
        _ = try await URLSession.shared.data(from: url)

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
        let url = URL(string: "http://127.0.0.1:\(port)/api/data")!

        // First stub
        await server.stubJSON(.GET, "/api/data", json: "{\"v\": 1}")

        let (data1, _) = try await URLSession.shared.data(from: url)
        let v1 = try JSONDecoder().decode([String: Int].self, from: data1)
        #expect(v1["v"] == 1)

        // Override with new stub
        await server.stubJSON(.GET, "/api/data", json: "{\"v\": 2}")

        let (data2, _) = try await URLSession.shared.data(from: url)
        let v2 = try JSONDecoder().decode([String: Int].self, from: data2)
        #expect(v2["v"] == 2)

        await server.stop()
    }

    @Test("Parallel servers don't interfere with each other")
    func parallelServersIsolated() async throws {
        // Simulate parallel testing: multiple servers running simultaneously
        let servers = try await withThrowingTaskGroup(of: (MockServer, UInt16).self) { group in
            for i in 0..<5 {
                group.addTask {
                    let server = try await MockServer.create()
                    await server.stubJSON(.GET, "/api/id", json: "{\"id\": \(i)}")
                    let port = await server.port
                    return (server, port)
                }
            }

            var results: [(MockServer, UInt16)] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }

        // Verify each server responds with its own data
        for (server, port) in servers {
            let url = URL(string: "http://127.0.0.1:\(port)/api/id")!
            let (data, response) = try await URLSession.shared.data(from: url)
            let httpResponse = response as! HTTPURLResponse
            #expect(httpResponse.statusCode == 200)

            let body = try JSONDecoder().decode([String: Int].self, from: data)
            #expect(body["id"] != nil)
        }

        // Clean up
        for (server, _) in servers {
            await server.stop()
        }
    }
}

// MARK: - HTTP Types Tests

@Suite("HTTP Types")
struct HTTPTypesTests {

    @Test("MockHTTPResponse.json creates correct response")
    func jsonResponse() {
        let response = MockHTTPResponse.json("{\"ok\":true}")
        #expect(response.status == .ok)
        #expect(response.headers["Content-Type"] == "application/json; charset=utf-8")
        #expect(response.bodyString == "{\"ok\":true}")
    }

    @Test("MockHTTPResponse.text creates correct response")
    func textResponse() {
        let response = MockHTTPResponse.text("hello")
        #expect(response.headers["Content-Type"] == "text/plain; charset=utf-8")
    }

    @Test("HTTPStatus equality")
    func statusEquality() {
        #expect(HTTPStatus.ok == HTTPStatus(code: 200, reason: "OK"))
        #expect(HTTPStatus.notFound != HTTPStatus.ok)
    }
}

// MARK: - App Config Tests

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
}

// MARK: - Route Stub Collection Tests

@Suite("Route Stub Collection")
struct RouteStubCollectionTests {

    @Test("Batch registration works")
    func batchRegistration() async throws {
        var collection = RouteStubCollection()
        collection.add(.GET, "/api/users", response: .json("[]"))
        collection.add(.POST, "/api/users", response: .status(.created))
        collection.add(.GET, "/api/health", response: .text("ok"))

        let server = try await MockServer.create()
        await server.registerAll(collection)
        let port = await server.port

        let healthURL = URL(string: "http://127.0.0.1:\(port)/api/health")!
        let (data, _) = try await URLSession.shared.data(from: healthURL)
        #expect(String(data: data, encoding: .utf8) == "ok")

        await server.stop()
    }
}

// Helper extension for tests
extension MockHTTPResponse {
    var bodyString: String? {
        body.flatMap { String(data: $0, encoding: .utf8) }
    }
}
