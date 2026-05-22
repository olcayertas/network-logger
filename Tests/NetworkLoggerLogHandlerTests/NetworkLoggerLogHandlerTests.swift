import Foundation
import Testing
import Logging
import NetworkLogger
@testable import NetworkLoggerLogHandler

@Suite("NetworkLoggerLogHandler")
struct NetworkLoggerLogHandlerTests {
    @Test("bridges Logger.Level to LogEvent.Level")
    func bridgesLevels() {
        #expect(NetworkLoggerLogHandler.bridge(.trace) == .trace)
        #expect(NetworkLoggerLogHandler.bridge(.debug) == .debug)
        #expect(NetworkLoggerLogHandler.bridge(.info) == .info)
        #expect(NetworkLoggerLogHandler.bridge(.notice) == .notice)
        #expect(NetworkLoggerLogHandler.bridge(.warning) == .warning)
        #expect(NetworkLoggerLogHandler.bridge(.error) == .error)
        #expect(NetworkLoggerLogHandler.bridge(.critical) == .critical)
    }

    @Test("emits a LogEvent into the logger's logStore")
    func emitsLogEvent() async throws {
        let networkLogger = NetworkLogger()
        var handler = NetworkLoggerLogHandler(label: "test.label", logger: networkLogger)
        handler.logLevel = .trace
        var logger = Logger(label: "test.label", factory: { _ in handler })
        logger.logLevel = .trace

        logger.info("hello world", metadata: ["userID": "42"])

        // The handler enqueues into a Task; give it a tick.
        try await Task.sleep(nanoseconds: 100_000_000)
        let events = await networkLogger.logStore.snapshot()
        #expect(events.count == 1)
        let first = try #require(events.first)
        #expect(first.label == "test.label")
        #expect(first.level == .info)
        #expect(first.message == "hello world")
        #expect(first.metadata["userID"] == "42")
    }

    @Test("merges handler-level and per-call metadata; per-call wins")
    func mergesMetadata() {
        let handler: Logger.Metadata = ["a": "1", "b": "2"]
        let call: Logger.Metadata = ["b": "3", "c": "4"]
        let merged = NetworkLoggerLogHandler.merge(handler: handler, call: call)
        #expect(merged["a"] == "1")
        #expect(merged["b"] == "3")
        #expect(merged["c"] == "4")
    }

    @Test("nil per-call metadata returns handler metadata unchanged")
    func nilCallMetadata() {
        let handler: Logger.Metadata = ["a": "1"]
        let merged = NetworkLoggerLogHandler.merge(handler: handler, call: nil)
        #expect(merged == handler)
    }
}
