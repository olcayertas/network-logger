import SwiftUI
import NetworkLogger
import NetworkLoggerMediaViewers

struct ContentView: View {
    let logger: NetworkLogger
    @State private var client: DemoNetworkClient?
    @State private var showLoggerSheet = false
    @State private var status = "Ready"

    var body: some View {
        NavigationStack {
            List {
                Section("Fire sample requests") {
                    Button("GET httpbin.org/get") { fireGet() }
                    Button("POST httpbin.org/post") { firePost() }
                    Button("Failing request") { fireFailing() }
                    Button("Record a fake gRPC call (manual)") { fireManual() }
                }

                Section("Present the logger") {
                    Button("Show as sheet") { showLoggerSheet = true }
                    NavigationLink("Push as navigation") {
                        NetworkLoggerView(logger: logger, bodyViewers: MediaBodyViewers.all)
                    }
                }

                Section("Status") {
                    Text(status).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("NetworkLogger Demo")
            .task {
                if client == nil {
                    client = await DemoNetworkClient(logger: logger)
                }
            }
            .sheet(isPresented: $showLoggerSheet) {
                NetworkLoggerView(logger: logger, bodyViewers: MediaBodyViewers.all)
            }
        }
    }

    private func fireGet() {
        Task {
            await client?.fire(url: URL(string: "https://httpbin.org/get")!)
            status = "Fired GET"
        }
    }

    private func firePost() {
        Task {
            await client?.firePost(url: URL(string: "https://httpbin.org/post")!,
                                   body: Data("{\"hello\":\"world\"}".utf8))
            status = "Fired POST"
        }
    }

    private func fireFailing() {
        Task {
            await client?.fire(url: URL(string: "https://nonexistent.example.test/path")!)
            status = "Fired (failing)"
        }
    }

    private func fireManual() {
        Task {
            let event = NetworkEvent(
                request: .init(
                    url: URL(string: "grpc://api.example.com/UserService/GetUser")!,
                    httpMethod: "POST",
                    headers: ["Content-Type": "application/grpc+proto"],
                    body: BodyData(data: Data("user_id: 42".utf8), contentType: "application/grpc+proto")
                ),
                response: .init(
                    statusCode: 0,
                    headers: ["grpc-status": "0"],
                    body: BodyData(data: Data("name: \"Alice\"".utf8))
                ),
                metrics: .init(duration: 0.085),
                state: .completed
            )
            await logger.record(event)
            status = "Manual gRPC event recorded"
        }
    }
}
