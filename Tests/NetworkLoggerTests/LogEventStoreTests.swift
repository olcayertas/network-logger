import Foundation
import Testing
@testable import NetworkLogger

@Suite("LogEventStore")
struct LogEventStoreTests {
    @Test("appends entries in order")
    func appendsInOrder() async {
        let store = LogEventStore(limit: 10)
        await store.append(LogEvent(level: .info, label: "app", message: "first"))
        await store.append(LogEvent(level: .warning, label: "app", message: "second"))
        let events = await store.snapshot()
        #expect(events.map(\.message) == ["first", "second"])
    }

    @Test("evicts oldest when over limit")
    func evictsOldest() async {
        let store = LogEventStore(limit: 2)
        await store.append(LogEvent(level: .info, label: "app", message: "a"))
        await store.append(LogEvent(level: .info, label: "app", message: "b"))
        await store.append(LogEvent(level: .info, label: "app", message: "c"))
        let events = await store.snapshot()
        #expect(events.map(\.message) == ["b", "c"])
    }

    @Test("clear empties the store")
    func clearEmpties() async {
        let store = LogEventStore(limit: 10)
        await store.append(LogEvent(level: .info, label: "x", message: "m"))
        await store.clear()
        let events = await store.snapshot()
        #expect(events.isEmpty)
    }

    @Test("level comparator")
    func levelComparator() {
        #expect(LogEvent.Level.trace < .debug)
        #expect(LogEvent.Level.error < .critical)
        #expect(LogEvent.Level.warning < .error)
        #expect(LogEvent.Level.notice > .info)
    }
}
