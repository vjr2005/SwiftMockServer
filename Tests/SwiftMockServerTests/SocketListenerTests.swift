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
}
