import Foundation
import Testing
@testable import NetworkLogger

@Suite("EventStore")
struct EventStoreTests {
    @Test("upsert appends new events")
    func upsertAppends() async {
        let store = EventStore(limit: 10)
        let event = makeEvent(url: "https://api.example.com/a")
        await store.upsert(event)

        let snapshot = await store.snapshot()
        #expect(snapshot.count == 1)
        #expect(snapshot.first?.id == event.id)
    }

    @Test("upsert replaces in place when id matches")
    func upsertReplaces() async {
        let store = EventStore(limit: 10)
        var event = makeEvent(url: "https://api.example.com/a")
        await store.upsert(event)

        event.state = .completed
        event.response = NetworkResponseSnapshot(statusCode: 200)
        await store.upsert(event)

        let snapshot = await store.snapshot()
        #expect(snapshot.count == 1)
        #expect(snapshot.first?.state == .completed)
        #expect(snapshot.first?.response?.statusCode == 200)
    }

    @Test("eviction drops oldest when over limit")
    func evictionDropsOldest() async {
        let store = EventStore(limit: 3)
        let a = makeEvent(url: "https://a")
        let b = makeEvent(url: "https://b")
        let c = makeEvent(url: "https://c")
        let d = makeEvent(url: "https://d")
        await store.upsert(a)
        await store.upsert(b)
        await store.upsert(c)
        await store.upsert(d)

        let snapshot = await store.snapshot()
        #expect(snapshot.count == 3)
        #expect(snapshot.map(\.id) == [b.id, c.id, d.id])
    }

    @Test("setLimit truncates current buffer")
    func setLimitTruncates() async {
        let store = EventStore(limit: 5)
        for i in 0..<5 {
            await store.upsert(makeEvent(url: "https://h/\(i)"))
        }
        await store.setLimit(2)

        let snapshot = await store.snapshot()
        #expect(snapshot.count == 2)
    }

    @Test("clear empties and broadcasts")
    func clearEmpties() async {
        let store = EventStore(limit: 10)
        await store.upsert(makeEvent(url: "https://a"))
        await store.clear()
        let snapshot = await store.snapshot()
        #expect(snapshot.isEmpty)
    }

    @Test("remove drops the matching event")
    func removeDrops() async {
        let store = EventStore(limit: 10)
        let a = makeEvent(url: "https://a")
        let b = makeEvent(url: "https://b")
        await store.upsert(a)
        await store.upsert(b)

        await store.remove(id: a.id)

        let snapshot = await store.snapshot()
        #expect(snapshot.count == 1)
        #expect(snapshot.first?.id == b.id)
    }

    @Test("stream yields initial snapshot, then upserts")
    func streamYields() async {
        let store = EventStore(limit: 10)
        let initial = makeEvent(url: "https://initial")
        await store.upsert(initial)

        let stream = await store.stream()
        var iterator = stream.makeAsyncIterator()

        let first = await iterator.next()
        #expect(first?.count == 1)
        #expect(first?.first?.id == initial.id)

        let next = makeEvent(url: "https://next")
        await store.upsert(next)

        let second = await iterator.next()
        #expect(second?.count == 2)
        #expect(second?.last?.id == next.id)
    }

    @Test("multiple streams fan out")
    func multipleStreamsFanOut() async {
        let store = EventStore(limit: 10)

        let s1 = await store.stream()
        let s2 = await store.stream()
        var i1 = s1.makeAsyncIterator()
        var i2 = s2.makeAsyncIterator()

        _ = await i1.next()
        _ = await i2.next()

        let event = makeEvent(url: "https://shared")
        await store.upsert(event)

        let a = await i1.next()
        let b = await i2.next()
        #expect(a?.first?.id == event.id)
        #expect(b?.first?.id == event.id)
    }

    private func makeEvent(url: String) -> NetworkEvent {
        NetworkEvent(
            request: NetworkRequestSnapshot(
                url: URL(string: url)!,
                httpMethod: "GET"
            )
        )
    }
}
