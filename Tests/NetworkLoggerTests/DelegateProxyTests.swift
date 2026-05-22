import Foundation
import Testing
@testable import NetworkLogger

@Suite("LoggingURLSessionDelegate")
struct DelegateProxyTests {

    @Test("captures GET 200 with body")
    func capturesSuccessfulGET() async throws {
        let host = "get-200.test"
        MockURLProtocol.install(host: host) { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("{\"ok\":true}".utf8))
        }
        defer { MockURLProtocol.reset(host: host) }

        let logger = NetworkLogger()
        let delegate = await logger.makeSessionDelegate()
        let session = URLSession(
            configuration: .mockEphemeral(),
            delegate: delegate,
            delegateQueue: nil
        )

        let url = URL(string: "https://\(host)/v1/items")!
        try await runAndWait(session: session, request: URLRequest(url: url), logger: logger)

        let event = try #require(await logger.snapshot().first)
        #expect(event.request.url == url)
        #expect(event.request.httpMethod == "GET")
        #expect(event.response?.statusCode == 200)
        #expect(event.response?.body?.data == Data("{\"ok\":true}".utf8))
        #expect(event.state == .completed)
    }

    @Test("captures POST with httpBody")
    func capturesPOST() async throws {
        let host = "post-body.test"
        MockURLProtocol.install(host: host) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (response, nil)
        }
        defer { MockURLProtocol.reset(host: host) }

        let logger = NetworkLogger()
        let delegate = await logger.makeSessionDelegate()
        let session = URLSession(configuration: .mockEphemeral(), delegate: delegate, delegateQueue: nil)

        var request = URLRequest(url: URL(string: "https://\(host)/v1/create")!)
        request.httpMethod = "POST"
        request.httpBody = Data("{\"name\":\"Tom\"}".utf8)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        try await runAndWait(session: session, request: request, logger: logger)

        let event = try #require(await logger.snapshot().first)
        #expect(event.request.httpMethod == "POST")
        #expect(event.request.body?.data == Data("{\"name\":\"Tom\"}".utf8))
        #expect(event.response?.statusCode == 201)
        #expect(event.state == .completed)
    }

    @Test("captures 4xx status")
    func capturesClientError() async throws {
        let host = "error-401.test"
        MockURLProtocol.install(host: host) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (response, Data("Unauthorized".utf8))
        }
        defer { MockURLProtocol.reset(host: host) }

        let logger = NetworkLogger()
        let delegate = await logger.makeSessionDelegate()
        let session = URLSession(configuration: .mockEphemeral(), delegate: delegate, delegateQueue: nil)

        try await runAndWait(
            session: session,
            request: URLRequest(url: URL(string: "https://\(host)/secure")!),
            logger: logger
        )

        let event = try #require(await logger.snapshot().first)
        #expect(event.response?.statusCode == 401)
        #expect(event.isClientError)
    }

    @Test("captures network failure")
    func capturesNetworkFailure() async throws {
        let host = "offline.test"
        MockURLProtocol.install(host: host) { _ in
            throw URLError(.notConnectedToInternet)
        }
        defer { MockURLProtocol.reset(host: host) }

        let logger = NetworkLogger()
        let delegate = await logger.makeSessionDelegate()
        let session = URLSession(configuration: .mockEphemeral(), delegate: delegate, delegateQueue: nil)

        try await runAndWait(
            session: session,
            request: URLRequest(url: URL(string: "https://\(host)/offline")!),
            logger: logger
        )

        let event = try #require(await logger.snapshot().first)
        #expect(event.state == .failed)
        #expect(event.error?.code == URLError.notConnectedToInternet.rawValue)
    }

    @Test("forwards callbacks to user delegate")
    func forwardsCallbacks() async throws {
        let host = "spy.test"
        MockURLProtocol.install(host: host) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (response, Data("hi".utf8))
        }
        defer { MockURLProtocol.reset(host: host) }

        let logger = NetworkLogger()
        let spy = SpyDelegate()
        let delegate = await logger.makeSessionDelegate(forwardingTo: spy)
        let session = URLSession(configuration: .mockEphemeral(), delegate: delegate, delegateQueue: nil)

        try await runAndWait(
            session: session,
            request: URLRequest(url: URL(string: "https://\(host)/spy")!),
            logger: logger
        )

        #expect(spy.didReceiveResponseCount == 1)
        #expect(spy.didReceiveDataCount >= 1)
        #expect(spy.didCompleteCount == 1)
    }

    @Test("user delegate auth challenge takes priority")
    func userAuthChallengeForwarded() async throws {
        let logger = NetworkLogger()
        let challenger = ChallengingDelegate()
        let delegate = await logger.makeSessionDelegate(forwardingTo: challenger)
        let session = URLSession(configuration: .mockEphemeral(), delegate: delegate, delegateQueue: nil)

        let space = URLProtectionSpace(
            host: "api.test",
            port: 443,
            protocol: "https",
            realm: nil,
            authenticationMethod: NSURLAuthenticationMethodServerTrust
        )
        let challenge = URLAuthenticationChallenge(
            protectionSpace: space,
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: NullChallengeSender()
        )

        let dispositionBox = AsyncBox<URLSession.AuthChallengeDisposition>()
        delegate.urlSession(session, didReceive: challenge) { disposition, _ in
            Task { await dispositionBox.set(disposition) }
        }

        let disposition = await dispositionBox.value()
        #expect(challenger.challengeCount == 1)
        #expect(disposition == .cancelAuthenticationChallenge)
    }

    private func runAndWait(
        session: URLSession,
        request: URLRequest,
        logger: NetworkLogger,
        timeout: TimeInterval = 2.0
    ) async throws {
        let task = session.dataTask(with: request)
        task.resume()

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

struct TestTimeout: Error {}

final class SpyDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private(set) var didReceiveResponseCount = 0
    private(set) var didReceiveDataCount = 0
    private(set) var didCompleteCount = 0

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @Sendable @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        didReceiveResponseCount += 1
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        didReceiveDataCount += 1
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        didCompleteCount += 1
    }
}

final class ChallengingDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    private(set) var challengeCount = 0

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @Sendable @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        challengeCount += 1
        completionHandler(.cancelAuthenticationChallenge, nil)
    }
}

final class NullChallengeSender: NSObject, URLAuthenticationChallengeSender {
    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {}
    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {}
    func cancel(_ challenge: URLAuthenticationChallenge) {}
}

actor AsyncBox<Value: Sendable> {
    private var stored: Value?
    private var waiters: [CheckedContinuation<Value, Never>] = []

    func set(_ value: Value) {
        stored = value
        for waiter in waiters {
            waiter.resume(returning: value)
        }
        waiters.removeAll()
    }

    func value() async -> Value {
        if let stored { return stored }
        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
}
