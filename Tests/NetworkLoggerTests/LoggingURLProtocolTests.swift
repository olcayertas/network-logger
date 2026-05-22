import Foundation
import Testing
@testable import NetworkLogger

@Suite("LoggingURLProtocol", .serialized)
struct LoggingURLProtocolTests {

    @Test("captures via URLProtocol path")
    func capturesViaURLProtocol() async throws {
        let host = "proto-200.test"
        let logger = NetworkLogger()
        LoggingURLProtocol.activate(logger)
        LoggingURLProtocol.underlyingProtocolClasses = [MockURLProtocol.self]
        defer {
            LoggingURLProtocol.deactivate()
            LoggingURLProtocol.underlyingProtocolClasses = []
        }

        MockURLProtocol.install(host: host) { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "text/plain"]
            )!
            return (response, Data("hello".utf8))
        }
        defer { MockURLProtocol.reset(host: host) }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [LoggingURLProtocol.self]
        let session = URLSession(configuration: config)

        let url = URL(string: "https://\(host)/proto")!
        session.dataTask(with: url).resume()

        try await waitFor(logger: logger, timeout: 2.0)

        let event = try #require(await logger.snapshot().first)
        #expect(event.request.url == url)
        #expect(event.response?.statusCode == 200)
        #expect(event.response?.body?.data == Data("hello".utf8))
        #expect(event.state == .completed)
    }

    @Test("challenge handler always calls completion (#157)")
    func challengeHandlerAlwaysCompletes() async throws {
        let host = "proto-challenge.test"
        let logger = NetworkLogger()
        LoggingURLProtocol.activate(logger)
        LoggingURLProtocol.underlyingProtocolClasses = [MockURLProtocol.self]
        defer {
            LoggingURLProtocol.deactivate()
            LoggingURLProtocol.underlyingProtocolClasses = []
        }

        MockURLProtocol.install(host: host) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (response, nil)
        }
        defer { MockURLProtocol.reset(host: host) }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [LoggingURLProtocol.self]
        let session = URLSession(configuration: config)

        session.dataTask(with: URL(string: "https://\(host)/secure")!).resume()
        try await waitFor(logger: logger, timeout: 2.0)

        let event = try #require(await logger.snapshot().first)
        #expect(event.state == .completed)
    }

    @Test("captures via attach API")
    func capturesViaAttach() async throws {
        let host = "proto-attach.test"
        let logger = NetworkLogger()
        LoggingURLProtocol.underlyingProtocolClasses = [MockURLProtocol.self]
        defer {
            LoggingURLProtocol.deactivate()
            LoggingURLProtocol.underlyingProtocolClasses = []
        }

        MockURLProtocol.install(host: host) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (response, nil)
        }
        defer { MockURLProtocol.reset(host: host) }

        let config = URLSessionConfiguration.ephemeral
        logger.attach(to: config)

        let session = URLSession(configuration: config)
        session.dataTask(with: URL(string: "https://\(host)/attached")!).resume()

        try await waitFor(logger: logger, timeout: 2.0)

        let event = try #require(await logger.snapshot().first)
        #expect(event.response?.statusCode == 204)
    }

    private func waitFor(logger: NetworkLogger, timeout: TimeInterval) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let events = await logger.snapshot()
            if let event = events.first, event.state != .inFlight {
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        throw TestTimeout()
    }
}
