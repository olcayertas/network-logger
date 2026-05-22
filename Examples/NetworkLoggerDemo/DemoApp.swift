import SwiftUI
import NetworkLogger

@main
struct DemoApp: App {
    @State private var logger: NetworkLogger = {
        let logger = NetworkLogger(configuration: .init(
            limit: 200,
            ignoredHosts: ["analytics.example.com"]
        ))
        return logger
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(logger: logger)
        }
    }
}
