// RouteStubCollectionTests.swift
// SwiftMockServerTests

import Testing
import Foundation
@testable import SwiftMockServer

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

        let healthURL = URL(string: "http://[::1]:\(port)/api/health")!
        let (data, _) = try await makeSession().data(from: healthURL)
        #expect(String(data: data, encoding: .utf8) == "ok")

        await server.stop()
    }

    @Test("Result builder init creates collection")
    func resultBuilderInit() {
        let collection = RouteStubCollection {
            RouteStubCollection.Stub(method: .GET, path: "/a", response: .status(.ok))
            RouteStubCollection.Stub(method: .POST, path: "/b", response: .status(.created))
        }

        #expect(collection.stubs.count == 2)
        #expect(collection.stubs[0].path == "/a")
        #expect(collection.stubs[1].path == "/b")
    }

    @Test("Result builder supports conditionals")
    func resultBuilderConditionals() {
        let useAuth = true
        let useAdmin = false

        let collection = RouteStubCollection {
            RouteStubCollection.Stub(path: "/api/health", response: .status(.ok))
            if useAuth {
                RouteStubCollection.Stub(method: .POST, path: "/api/login", response: .status(.ok))
            }
            if useAdmin {
                RouteStubCollection.Stub(method: .GET, path: "/api/admin", response: .status(.ok))
            }
        }

        #expect(collection.stubs.count == 2)
        #expect(collection.stubs[1].path == "/api/login")
    }

    @Test("Result builder supports if-else branches")
    func resultBuilderIfElse() {
        let useMock = true

        let collectionA = RouteStubCollection {
            if useMock {
                RouteStubCollection.Stub(path: "/mock", response: .status(.ok))
            } else {
                RouteStubCollection.Stub(path: "/real", response: .status(.ok))
            }
        }

        #expect(collectionA.stubs.count == 1)
        #expect(collectionA.stubs[0].path == "/mock")

        let collectionB = RouteStubCollection {
            if !useMock {
                RouteStubCollection.Stub(path: "/mock", response: .status(.ok))
            } else {
                RouteStubCollection.Stub(path: "/real", response: .status(.ok))
            }
        }

        #expect(collectionB.stubs.count == 1)
        #expect(collectionB.stubs[0].path == "/real")
    }

    @Test("Result builder supports for-in loops")
    func resultBuilderForLoop() {
        let paths = ["/a", "/b", "/c"]

        let collection = RouteStubCollection {
            for path in paths {
                RouteStubCollection.Stub(path: path, response: .status(.ok))
            }
        }

        #expect(collection.stubs.count == 3)
        #expect(collection.stubs.map { $0.path } == paths)
    }
}
