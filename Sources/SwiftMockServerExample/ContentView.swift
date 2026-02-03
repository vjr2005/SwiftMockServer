import SwiftUI
import SwiftMockServer

// MARK: - ContentView

struct ContentView: View {
    @State private var viewModel = MockServerViewModel()

    var body: some View {
        NavigationStack {
            List {
                serverStatusSection
                routesSection
                requestLogSection
                actionsSection
            }
            .navigationTitle("MockServer Demo")
            .task {
                await viewModel.startServer()
            }
            .onDisappear {
                Task { await viewModel.stopServer() }
            }
        }
    }

    // MARK: - Sections

    private var serverStatusSection: some View {
        Section("Server Status") {
            HStack {
                Circle()
                    .fill(viewModel.isRunning ? .green : .red)
                    .frame(width: 10, height: 10)
                Text(viewModel.isRunning ? "Running" : "Stopped")
                    .font(.headline)
            }

            if let port = viewModel.port {
                LabeledContent("Port", value: "\(port)")
            }

            if let url = viewModel.baseURL {
                LabeledContent("Base URL", value: url)
                    .font(.caption)
            }
        }
    }

    private var routesSection: some View {
        Section("Registered Routes") {
            if viewModel.registeredRoutes.isEmpty {
                Text("No routes registered")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.registeredRoutes, id: \.self) { route in
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(.blue)
                        Text(route)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
        }
    }

    private var requestLogSection: some View {
        Section("Requests Received (\(viewModel.requestLog.count))") {
            if viewModel.requestLog.isEmpty {
                Text("No requests received yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(viewModel.requestLog.enumerated()), id: \.offset) { _, entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.method)
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Text(entry.path)
                            .font(.system(.body, design: .monospaced))
                        Text(entry.timestamp)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var actionsSection: some View {
        Section("Actions") {
            Button("Register Sample Routes") {
                Task { await viewModel.registerSampleRoutes() }
            }

            Button("Send Test Request") {
                Task { await viewModel.sendTestRequest() }
            }
            .disabled(!viewModel.isRunning)

            Button("Clear Request Log") {
                viewModel.requestLog.removeAll()
            }

            Button(viewModel.isRunning ? "Stop Server" : "Start Server") {
                Task {
                    if viewModel.isRunning {
                        await viewModel.stopServer()
                    } else {
                        await viewModel.startServer()
                    }
                }
            }
            .foregroundStyle(viewModel.isRunning ? .red : .green)
        }
    }
}

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
                baseURL = "http://127.0.0.1:\(p)"
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

// MARK: - Preview

#Preview {
    ContentView()
}
