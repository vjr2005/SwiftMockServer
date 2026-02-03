// SocketListener.swift
// SwiftMockServer
//
// Low-level TCP listener using DispatchSource for non-blocking I/O.
// No thread is ever blocked — accept, read, and write are all event-driven.

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
import Foundation

// MARK: - Connection Handler

/// A Sendable closure that handles a parsed request and returns a response.
/// Called on the actor — must not perform blocking I/O.
typealias ConnectionHandler = @Sendable (MockHTTPRequest) async -> MockHTTPResponse

// MARK: - Socket Listener

/// Manages a listening TCP socket using DispatchSource for fully non-blocking I/O.
/// No thread is ever blocked — accept and read are event-driven via GCD sources.
actor SocketListener {

    private var serverFD: Int32 = -1
    private var isListening = false
    private var acceptSource: DispatchSourceRead?
    private let assignedPort: UInt16
    private let acceptQueue: DispatchQueue

    /// The port this listener is bound to.
    var port: UInt16 { assignedPort }

    /// Initialize and bind to a port. Pass 0 for automatic port assignment.
    /// Uses IPv4 loopback (127.0.0.1) for maximum compatibility with URLSession.
    init(port: UInt16 = 0) throws {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw MockServerError.bindFailed("Cannot create socket: \(String(cString: strerror(errno)))")
        }

        // Allow address reuse (avoids EADDRINUSE after quick restart)
        var reuse: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        // Set non-blocking mode
        let flags = fcntl(fd, F_GETFL)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

        // Bind to IPv4 loopback
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = UInt32(INADDR_LOOPBACK).bigEndian

        let bindResult = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(fd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard bindResult == 0 else {
            close(fd)
            throw MockServerError.bindFailed("Bind failed on port \(port): \(String(cString: strerror(errno)))")
        }

        // Determine actual port (important when port == 0)
        var boundAddr = sockaddr_in()
        var boundLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        getsockname(fd, withUnsafeMutablePointer(to: &boundAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0 }
        }, &boundLen)

        self.assignedPort = UInt16(bigEndian: boundAddr.sin_port)
        self.serverFD = fd
        self.acceptQueue = DispatchQueue(label: "MockServer.accept.\(assignedPort)")
    }

    /// Start listening for connections.
    /// Uses DispatchSource for non-blocking accept — no thread is blocked.
    func start(backlog: Int32 = 128, handler: @escaping ConnectionHandler) throws {
        guard !isListening else {
            throw MockServerError.alreadyRunning
        }

        guard listen(serverFD, backlog) == 0 else {
            throw MockServerError.listenFailed("Listen failed: \(String(cString: strerror(errno)))")
        }

        isListening = true
        let fd = serverFD

        // DispatchSource fires when the server socket has pending connections.
        // No thread blocks on accept() — GCD notifies us via kqueue.
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: acceptQueue)
        source.setEventHandler {
            // Drain all pending connections
            while true {
                var clientAddr = sockaddr_in()
                var clientAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)

                let clientFD = withUnsafeMutablePointer(to: &clientAddr) { addrPtr in
                    addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                        accept(fd, sockaddrPtr, &clientAddrLen)
                    }
                }

                if clientFD < 0 {
                    break // EWOULDBLOCK — no more pending connections
                }

                ConnectionDispatcher.handle(clientFD: clientFD, using: handler)
            }
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        acceptSource = source
    }

    /// Stop listening and release the socket.
    func stop() {
        if let source = acceptSource {
            source.cancel()
            acceptSource = nil
            serverFD = -1
        } else if serverFD >= 0 {
            close(serverFD)
            serverFD = -1
        }
        isListening = false
    }

    deinit {
        acceptSource?.cancel()
        if serverFD >= 0 {
            close(serverFD)
        }
    }
}

// MARK: - Connection Dispatcher

/// Handles a single client connection using DispatchSource for non-blocking read.
/// Completely event-driven — no thread is ever blocked.
enum ConnectionDispatcher: Sendable {

    static func handle(clientFD: Int32, using handler: @escaping ConnectionHandler) {
        // Set a short read timeout as safety net (localhost data arrives in <1ms)
        var timeout = timeval(tv_sec: 2, tv_usec: 0)
        setsockopt(clientFD, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        let ioQueue = DispatchQueue(label: "MockServer.io.\(clientFD)")

        let source = DispatchSource.makeReadSource(fileDescriptor: clientFD, queue: ioQueue)
        // Use nonisolated(unsafe) for the mutable state managed by the serial ioQueue
        nonisolated(unsafe) var buffer = Data()
        nonisolated(unsafe) var readSource: DispatchSourceRead? = source

        source.setEventHandler {
            let chunk = Self.readAvailable(from: clientFD)

            if chunk.isEmpty {
                // Connection closed or error — clean up
                readSource?.cancel()
                readSource = nil
                Self.closeConnection(clientFD)
                return
            }

            buffer.append(chunk)

            // Try to parse — if we have a complete request, process it
            guard let request = try? HTTPParser.parse(buffer) else {
                return // Wait for more data
            }

            // Got a complete request — stop reading and process
            readSource?.cancel()
            readSource = nil

            Task {
                let response = await handler(request)
                let responseData = HTTPParser.serialize(response)
                ioQueue.async {
                    Self.writeAll(to: clientFD, data: responseData)
                    Self.closeConnection(clientFD)
                }
            }
        }

        source.setCancelHandler {
            // No-op: clientFD is closed explicitly after writing
        }

        source.resume()
    }

    // MARK: - Socket I/O (non-blocking)

    /// Read all currently available data from a socket (non-blocking).
    private static func readAvailable(from fd: Int32) -> Data {
        var data = Data()
        let bufferSize = 65536
        let rawBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { rawBuffer.deallocate() }

        while true {
            let bytesRead = recv(fd, rawBuffer, bufferSize, 0)
            if bytesRead > 0 {
                data.append(rawBuffer, count: bytesRead)
                if bytesRead < bufferSize { break } // Got everything available
            } else {
                break // EWOULDBLOCK, EOF, or error
            }
        }

        return data
    }

    /// Write all data to a socket.
    private static func writeAll(to fd: Int32, data: Data) {
        data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            var totalSent = 0
            let count = data.count
            while totalSent < count {
                let sent = send(fd, baseAddress.advanced(by: totalSent), count - totalSent, 0)
                if sent <= 0 { break }
                totalSent += sent
            }
        }
    }

    /// Close a client connection.
    private static func closeConnection(_ fd: Int32) {
        shutdown(fd, SHUT_RDWR)
        close(fd)
    }
}
