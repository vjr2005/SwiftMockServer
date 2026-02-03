// SocketListenerTests.swift
// SwiftMockServerTests

import Testing
import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
@testable import SwiftMockServer

@Suite("SocketListener")
struct SocketListenerTests {

    @Test("Bind fails on port already in use")
    func bindFailsOnPortInUse() async throws {
        // Bind first listener to a specific port
        let listener1 = try SocketListener(port: 0)
        let port = await listener1.port

        // Second listener on the same port should fail
        #expect(throws: MockServerError.self) {
            _ = try SocketListener(port: port)
        }

        await listener1.stop()
    }

    @Test("Stop without start closes socket cleanly")
    func stopWithoutStart() async throws {
        let listener = try SocketListener(port: 0)
        // stop() without start() takes the else branch (no acceptSource)
        await listener.stop()
    }

    @Test("Double start throws alreadyRunning")
    func doubleStartThrows() async throws {
        let listener = try SocketListener(port: 0)
        try await listener.start { _ in .status(.ok) }

        await #expect(throws: MockServerError.self) {
            try await listener.start { _ in .status(.ok) }
        }

        await listener.stop()
    }

    @Test("Deinit closes socket when not started")
    func deinitClosesSocket() throws {
        // Create and immediately drop — deinit should close the fd
        _ = try SocketListener(port: 0)
        // No crash or leak = success
    }

    @Test("Handles client that connects and immediately disconnects")
    func clientDisconnectsImmediately() async throws {
        let server = try await MockServer.create()
        let port = await server.port

        // Open a raw TCP connection and close it without sending data
        let fd = socket(AF_INET6, SOCK_STREAM, 0)
        var addr = sockaddr_in6()
        addr.sin6_family = sa_family_t(AF_INET6)
        addr.sin6_port = port.bigEndian
        addr.sin6_addr = in6addr_loopback

        withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                _ = connect(fd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in6>.size))
            }
        }
        close(fd)

        // Give time for the empty-read cleanup path to execute
        try await Task.sleep(for: .milliseconds(100))

        await server.stop()
    }

    @Test("Handles partial HTTP data arriving in chunks")
    func partialDataChunks() async throws {
        let server = try await MockServer.create()
        let port = await server.port

        await server.stub(.GET, "/chunked", response: .text("ok"))

        // Send a valid HTTP request in two separate writes with a delay
        let fd = socket(AF_INET6, SOCK_STREAM, 0)
        var addr = sockaddr_in6()
        addr.sin6_family = sa_family_t(AF_INET6)
        addr.sin6_port = port.bigEndian
        addr.sin6_addr = in6addr_loopback

        withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                _ = connect(fd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in6>.size))
            }
        }

        // Send partial request (no \r\n\r\n terminator yet)
        let partial = "GET /chunked HTTP/1.1\r\nHost: localhost\r\n"
        _ = partial.withCString { send(fd, $0, strlen($0), 0) }

        // Wait so the server reads partial data and hits the "wait for more" return
        try await Task.sleep(for: .milliseconds(200))

        // Now send the rest to complete the request
        let rest = "\r\n"
        _ = rest.withCString { send(fd, $0, strlen($0), 0) }

        // Read the response
        var buf = [UInt8](repeating: 0, count: 4096)
        try await Task.sleep(for: .milliseconds(200))
        let n = recv(fd, &buf, buf.count, 0)
        close(fd)

        let response = n > 0 ? String(bytes: buf[..<n], encoding: .utf8) : nil
        #expect(response?.contains("ok") == true)

        await server.stop()
    }

    @Test("Listen fails on closed socket")
    func listenFailsOnClosedSocket() async throws {
        let listener = try SocketListener(port: 0)
        // stop() closes the fd, making listen() fail on next start()
        await listener.stop()

        await #expect(throws: MockServerError.self) {
            try await listener.start { _ in .status(.ok) }
        }
    }

    @Test("Stop cancels in-flight slow handler")
    func stopCancelsInFlightHandler() async throws {
        let handlerStarted = LockedFlag()
        let handlerCancelled = LockedFlag()

        let server = try await MockServer.create()
        let port = await server.port

        await server.register(.GET, "/slow") { _ in
            handlerStarted.set()
            do {
                // Sleep long enough that stop() will interrupt us
                try await Task.sleep(for: .seconds(30))
            } catch {
                // CancellationError means stop() cancelled the task
                handlerCancelled.set()
            }
            return .status(.ok)
        }

        // Fire a request to trigger the slow handler
        let fd = Self.connectTo(port: port)
        let req = "GET /slow HTTP/1.1\r\nHost: localhost\r\n\r\n"
        _ = req.withCString { send(fd, $0, strlen($0), 0) }

        // Wait for the handler to start
        while !handlerStarted.isSet {
            try await Task.sleep(for: .milliseconds(10))
        }

        // Stop the server — should cancel the in-flight task
        await server.stop()

        // Give a moment for cancellation to propagate
        try await Task.sleep(for: .milliseconds(100))

        #expect(handlerCancelled.isSet)
        close(fd)
    }

    @Test("Stop cleans up connection still reading data")
    func stopCleansUpReadingConnection() async throws {
        let server = try await MockServer.create()
        let port = await server.port

        await server.stub(.GET, "/test", response: .text("ok"))

        // Connect but send only partial data (no \r\n\r\n terminator)
        let fd = Self.connectTo(port: port)
        let partial = "GET /test HTTP/1.1\r\nHost: localhost\r\n"
        _ = partial.withCString { send(fd, $0, strlen($0), 0) }

        // Give the server time to start reading
        try await Task.sleep(for: .milliseconds(100))

        // Stop should clean up the partially-read connection
        await server.stop()

        // Verify the connection was closed by the server — writing more data
        // should eventually fail because the server closed its end
        try await Task.sleep(for: .milliseconds(50))
        let probe = "X"
        let sent1 = probe.withCString { send(fd, $0, 1, 0) }
        // First send may succeed (buffered locally), so try again after a delay
        if sent1 > 0 {
            try await Task.sleep(for: .milliseconds(50))
            let sent2 = probe.withCString { send(fd, $0, 1, 0) }
            // Second send should fail with EPIPE or ECONNRESET, or recv returns 0
            if sent2 > 0 {
                var buf = [UInt8](repeating: 0, count: 64)
                let n = recv(fd, &buf, buf.count, 0)
                #expect(n <= 0)
            }
        }
        close(fd)
    }

    @Test("Stop then start works correctly")
    func stopThenStartWorks() async throws {
        let server = try await MockServer.create()

        await server.stub(.GET, "/ping", response: .text("pong"))

        let session = makeSession()

        // Verify first start works
        let url1 = URL(string: await server.baseURL + "/ping")!
        let (data1, _) = try await session.data(from: url1)
        let body1 = String(data: data1, encoding: .utf8)
        #expect(body1 == "pong")

        await server.stop()

        // Start again
        try await server.start()

        // Re-register routes (routes survive stop, but let's stub again to be explicit)
        await server.stub(.GET, "/ping2", response: .text("pong2"))

        let url2 = URL(string: await server.baseURL + "/ping2")!
        let (data2, _) = try await session.data(from: url2)
        let body2 = String(data: data2, encoding: .utf8)
        #expect(body2 == "pong2")

        await server.stop()
    }

    // MARK: - Helpers

    private static func connectTo(port: UInt16) -> Int32 {
        let fd = socket(AF_INET6, SOCK_STREAM, 0)
        var addr = sockaddr_in6()
        addr.sin6_family = sa_family_t(AF_INET6)
        addr.sin6_port = port.bigEndian
        addr.sin6_addr = in6addr_loopback

        withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                _ = connect(fd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in6>.size))
            }
        }
        return fd
    }
}

/// Thread-safe boolean flag for test synchronization.
private final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    var isSet: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func set() {
        lock.lock()
        value = true
        lock.unlock()
    }
}
