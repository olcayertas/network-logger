import Dependencies
import Foundation
import NetworkLogger
import NetworkLoggerDependencies
import Testing

@Suite("Dependencies integration")
struct DependencyIntegrationTests {
    @Test("override propagates to consumers")
    func overridePropagates() async {
        let custom = NetworkLogger(configuration: .init(limit: 7))
        let resolved = await withDependencies {
            $0.networkLogger = custom
        } operation: {
            @Dependency(\.networkLogger) var logger
            return logger
        }
        let config = await resolved.configuration()
        #expect(config.limit == 7)
    }

    @Test("default liveValue is usable")
    func defaultLiveValue() async {
        let resolved = withDependencies {
            $0.context = .live
        } operation: {
            @Dependency(\.networkLogger) var logger
            return logger
        }
        await resolved.record(NetworkEvent(
            request: NetworkRequestSnapshot(
                url: URL(string: "https://default.test/path")!,
                httpMethod: "GET"
            )
        ))
        let events = await resolved.snapshot()
        #expect(events.count == 1)
    }

    @Test("testValue is isolated per scope")
    func testValueIsolated() async {
        @Dependency(\.networkLogger) var logger
        let snapshot = await logger.snapshot()
        #expect(snapshot.isEmpty)
    }
}
