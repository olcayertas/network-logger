import Foundation
import NetworkLogger

actor DemoNetworkClient {
    private let session: URLSession

    init(logger: NetworkLogger) async {
        let delegate = await logger.makeSessionDelegate()
        self.session = URLSession(
            configuration: .default,
            delegate: delegate,
            delegateQueue: nil
        )
    }

    func fire(url: URL) async {
        let task = session.dataTask(with: url)
        task.resume()
        // Wait for completion the delegate-driven way.
        await withCheckedContinuation { continuation in
            Task {
                while task.state != .completed {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
                continuation.resume()
            }
        }
    }

    func firePost(url: URL, body: Data) async {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let task = session.dataTask(with: request)
        task.resume()
        await withCheckedContinuation { continuation in
            Task {
                while task.state != .completed {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
                continuation.resume()
            }
        }
    }
}
