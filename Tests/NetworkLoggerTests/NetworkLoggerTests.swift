import Foundation
import Testing
@testable import NetworkLogger

@Suite("NetworkLogger facade")
struct NetworkLoggerFacadeTests {
    @Test("manual record adds to store")
    func recordAddsToStore() async {
        let logger = NetworkLogger()
        await logger.record(makeEvent(url: "https://api.example.com/a"))
        let snapshot = await logger.snapshot()
        #expect(snapshot.count == 1)
    }

    @Test("record skips ignored hosts")
    func recordSkipsIgnoredHosts() async {
        let logger = NetworkLogger(
            configuration: .init(ignoredHosts: ["analytics.example.com"])
        )
        await logger.record(makeEvent(url: "https://analytics.example.com/track"))
        await logger.record(makeEvent(url: "https://api.example.com/users"))
        let snapshot = await logger.snapshot()
        #expect(snapshot.count == 1)
        #expect(snapshot.first?.request.host == "api.example.com")
    }

    @Test("header redactor sanitizes Authorization")
    func headerRedactorRuns() async {
        let logger = NetworkLogger()
        let event = makeEvent(
            url: "https://api.example.com/a",
            requestHeaders: ["Authorization": "Bearer secret", "Accept": "application/json"]
        )
        await logger.record(event)
        let stored = await logger.snapshot().first
        #expect(stored?.request.headers["Authorization"] == "•••redacted•••")
        #expect(stored?.request.headers["Accept"] == "application/json")
    }

    @Test("JWT is decoded before redaction runs")
    func jwtDecodedBeforeRedaction() async {
        // header={"alg":"HS256","typ":"JWT"} payload={"sub":"alice","exp":1516239322}
        let token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9" +
            ".eyJzdWIiOiJhbGljZSIsImV4cCI6MTUxNjIzOTMyMn0.sig"
        let logger = NetworkLogger()
        let event = makeEvent(
            url: "https://api.example.com/a",
            requestHeaders: ["Authorization": "Bearer \(token)"]
        )
        await logger.record(event)
        let stored = await logger.snapshot().first
        // Raw value is redacted as before…
        #expect(stored?.request.headers["Authorization"] == "•••redacted•••")
        // …but the decoded JWT is preserved under the lowercased header name.
        #expect(stored?.request.decodedJWTs["authorization"]?.claims.sub == "alice")
    }

    @Test("response Authorization JWT decoded before redaction")
    func responseJWTDecoded() async {
        let token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJib2IifQ.sig"
        let logger = NetworkLogger()
        var event = makeEvent(url: "https://api.example.com/a")
        event.response = NetworkResponseSnapshot(
            statusCode: 200,
            headers: ["Authorization": "Bearer \(token)"]
        )
        await logger.record(event)
        let stored = await logger.snapshot().first
        #expect(stored?.response?.headers["Authorization"] == "•••redacted•••")
        #expect(stored?.response?.decodedJWTs["authorization"]?.claims.sub == "bob")
    }

    @Test("non-JWT header values produce no decoded entry")
    func nonJWTHeaderProducesNothing() async {
        let logger = NetworkLogger()
        let event = makeEvent(
            url: "https://api.example.com/a",
            requestHeaders: ["X-Request-ID": "abc-123"]
        )
        await logger.record(event)
        let stored = await logger.snapshot().first
        #expect(stored?.request.decodedJWTs.isEmpty == true)
    }

    @Test("response transformer rewrites body")
    func responseTransformerRuns() async {
        let logger = NetworkLogger(
            configuration: .init(
                responseTransformer: { _, _ in Data("transformed".utf8) }
            )
        )
        var event = makeEvent(url: "https://api.example.com/a")
        event.response = NetworkResponseSnapshot(
            statusCode: 200,
            body: BodyData(data: Data("original".utf8))
        )
        await logger.record(event)
        let stored = await logger.snapshot().first
        #expect(stored?.response?.body?.data == Data("transformed".utf8))
    }

    @Test("setLimit propagates to store")
    func setLimitTruncates() async {
        let logger = NetworkLogger(configuration: .init(limit: 10))
        for i in 0..<5 {
            await logger.record(makeEvent(url: "https://h/\(i)"))
        }
        await logger.setLimit(2)
        let snapshot = await logger.snapshot()
        #expect(snapshot.count == 2)
    }

    @Test("eventStream yields on record")
    func eventStreamYields() async {
        let logger = NetworkLogger()
        let stream = await logger.eventStream()
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next()

        await logger.record(makeEvent(url: "https://api.example.com/a"))
        let next = await iterator.next()
        #expect(next?.count == 1)
    }

    private func makeEvent(
        url: String,
        requestHeaders: [String: String] = [:]
    ) -> NetworkEvent {
        NetworkEvent(
            request: NetworkRequestSnapshot(
                url: URL(string: url)!,
                httpMethod: "GET",
                headers: requestHeaders
            )
        )
    }
}
