// ConnectionTracker.swift
// SwiftMockServer
//
// Thread-safe tracker for active client connections.
// Uses NSLock to allow safe access from GCD queues and Swift concurrency.

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
import Foundation

/// Tracks active client connections so they can be cancelled when the server stops.
///
/// Thread-safe via `NSLock`. Marked `@unchecked Sendable` because all mutable
/// state is protected by the lock.
final class ConnectionTracker: @unchecked Sendable {

    struct ConnectionEntry {
        let clientFD: Int32
        var readSource: DispatchSourceRead?
        var task: Task<Void, Never>?
    }

    private let lock = NSLock()
    private var connections: [UUID: ConnectionEntry] = [:]
    private var isCancelled = false

    /// Register a new connection. Returns `nil` if the tracker has been cancelled
    /// (i.e., `cancelAll()` was already called), in which case the caller should
    /// close the FD and bail out.
    func register(clientFD: Int32, readSource: DispatchSourceRead) -> UUID? {
        lock.lock()
        defer { lock.unlock() }

        guard !isCancelled else { return nil }

        let id = UUID()
        connections[id] = ConnectionEntry(
            clientFD: clientFD,
            readSource: readSource,
            task: nil
        )
        return id
    }

    /// Associate the handler `Task` with a tracked connection.
    /// If the connection was already removed (by `cancelAll()`), the task is
    /// cancelled immediately to prevent orphaned work.
    func setTask(_ task: Task<Void, Never>, for id: UUID) {
        lock.lock()
        if connections[id] != nil {
            connections[id]!.task = task
            lock.unlock()
        } else {
            lock.unlock()
            task.cancel()
        }
    }

    /// Remove a connection from tracking. Returns `false` if the entry was
    /// already removed (by `cancelAll()` or a prior `deregister` call),
    /// signaling the caller should **not** close the FD (it's already handled).
    @discardableResult
    func deregister(_ id: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return connections.removeValue(forKey: id) != nil
    }

    /// Cancel all tracked connections: cancel their read sources and tasks,
    /// and close their file descriptors. After this call, new `register` calls
    /// return `nil`.
    func cancelAll() {
        lock.lock()
        isCancelled = true
        let snapshot = connections
        connections.removeAll()
        lock.unlock()

        for entry in snapshot.values {
            entry.readSource?.cancel()
            entry.task?.cancel()
            Self.closeConnection(entry.clientFD)
        }
    }

    /// Reset the cancelled flag so the tracker can be reused after a stop/start cycle.
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        isCancelled = false
    }

    private static func closeConnection(_ fd: Int32) {
        var ling = linger(l_onoff: 1, l_linger: 0)
        setsockopt(fd, SOL_SOCKET, SO_LINGER, &ling, socklen_t(MemoryLayout<linger>.size))
        close(fd)
    }
}
