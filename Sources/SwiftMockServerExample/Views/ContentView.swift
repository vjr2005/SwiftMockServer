import SwiftUI

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

// MARK: - Preview

#Preview {
    ContentView()
}
