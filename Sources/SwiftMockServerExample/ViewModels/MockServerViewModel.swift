import Foundation
import SwiftMockServer

// MARK: - ViewModel

@Observable
@MainActor
final class MockServerViewModel {
    var isRunning = false
    var port: UInt16?
    var baseURL: String?
    var registeredRoutes: [String] = []
    var requestLog: [RequestEntry] = []

    private var server: MockServer?

    struct RequestEntry: Sendable {
        let method: String
        let path: String
        let timestamp: String
    }

    func startServer() async {
        let newServer = MockServer()
        server = newServer

        do {
            try await newServer.start()
            isRunning = true
            port = await newServer.port
            if let p = port {
                baseURL = "http://localhost:\(p)"
            }
        } catch {
            isRunning = false
            print("Failed to start server: \(error)")
        }
    }

    func stopServer() async {
        guard let server else { return }
        await server.stop()
        isRunning = false
        port = nil
        baseURL = nil
        registeredRoutes.removeAll()
        self.server = nil
    }

    func registerSampleRoutes() async {
        guard let server else { return }

        // GET /api/users
        await server.stubJSON(
            .GET, "/api/users",
            json: """
            [
                {"id": 1, "name": "Alice Johnson", "email": "alice@example.com"},
                {"id": 2, "name": "Bob Smith", "email": "bob@example.com"},
                {"id": 3, "name": "Carol Williams", "email": "carol@example.com"}
            ]
            """
        )

        // GET /api/users/:id
        await server.registerParameterized(.GET, "/api/users/:id") { request in
            let userId = request.path.split(separator: "/").last.map(String.init) ?? "0"
            return .json("""
            {"id": \(userId), "name": "User \(userId)", "email": "user\(userId)@example.com"}
            """)
        }

        // POST /api/users
        await server.register(.POST, "/api/users") { _ in
            .json("""
            {"id": 4, "name": "New User", "created": true}
            """, status: .created)
        }

        // GET /api/health
        await server.register(.GET, "/api/health") { _ in
            .json("""
            {"status": "ok", "uptime": 42}
            """)
        }

        // DELETE /api/users/:id
        await server.registerParameterized(.DELETE, "/api/users/:id") { _ in
            .status(.noContent)
        }

        registeredRoutes = [
            "GET  /api/users",
            "GET  /api/users/:id",
            "POST /api/users",
            "GET  /api/health",
            "DELETE /api/users/:id",
        ]
    }

    func sendTestRequest() async {
        guard let baseURL, let url = URL(string: "\(baseURL)/api/users") else { return }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            let httpResponse = response as? HTTPURLResponse

            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"

            requestLog.insert(
                RequestEntry(
                    method: "GET → \(httpResponse?.statusCode ?? 0)",
                    path: "/api/users",
                    timestamp: formatter.string(from: Date())
                ),
                at: 0
            )
        } catch {
            print("Test request failed: \(error)")
        }
    }
}
