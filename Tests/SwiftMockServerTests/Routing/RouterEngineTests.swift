// RouterEngineTests.swift
// SwiftMockServerTests

import Testing
@testable import SwiftMockServer

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

    @Test("Skips non-matching exact route and matches next")
    func skipsNonMatchingExact() {
        let miss = Route(method: .GET, pattern: .exact("/other"), handler: { _ in .status(.ok) })
        let hit = Route(method: .GET, pattern: .exact("/target"), handler: { _ in .status(.ok) })

        let request = MockHTTPRequest(method: .GET, path: "/target")
        let match = RouterEngine.match(request: request, routes: [miss, hit])

        #expect(match?.route.id == hit.id)
    }

    @Test("Parameterized pattern rejects different segment count")
    func parameterizedSegmentMismatch() {
        let route = Route(
            method: .GET,
            pattern: .parameterized("/users/:id"),
            handler: { _ in .status(.ok) }
        )

        let request = MockHTTPRequest(method: .GET, path: "/users/42/extra")
        let match = RouterEngine.match(request: request, routes: [route])

        #expect(match == nil)
    }

    @Test("Parameterized pattern supports wildcard segments")
    func parameterizedWildcard() {
        let route = Route(
            method: .GET,
            pattern: .parameterized("/files/*/download"),
            handler: { _ in .status(.ok) }
        )

        let request = MockHTTPRequest(method: .GET, path: "/files/abc123/download")
        let match = RouterEngine.match(request: request, routes: [route])

        #expect(match != nil)
        #expect(match?.pathParameters.isEmpty == true)
    }

    @Test("Parameterized pattern rejects mismatched literal segment")
    func parameterizedLiteralMismatch() {
        let route = Route(
            method: .GET,
            pattern: .parameterized("/api/users/:id"),
            handler: { _ in .status(.ok) }
        )

        let request = MockHTTPRequest(method: .GET, path: "/api/posts/42")
        let match = RouterEngine.match(request: request, routes: [route])

        #expect(match == nil)
    }

    @Test("Normalizes path without leading slash")
    func normalizesPathWithoutLeadingSlash() {
        let route = Route(
            method: .GET,
            pattern: .exact("/api/test"),
            handler: { _ in .status(.ok) }
        )

        let request = MockHTTPRequest(method: .GET, path: "api/test")
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
