import Foundation

public actor EventStore {
    private var events: [NetworkEvent] = []
    private var limit: Int
    private var continuations: [UUID: AsyncStream<[NetworkEvent]>.Continuation] = [:]

    public init(limit: Int = 500) {
        self.limit = max(1, limit)
    }

    public func setLimit(_ newLimit: Int) {
        limit = max(1, newLimit)
        evictIfNeeded()
        broadcast()
    }

    public func upsert(_ event: NetworkEvent) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
        } else {
            events.append(event)
            evictIfNeeded()
        }
        broadcast()
    }

    public func remove(id: UUID) {
        let before = events.count
        events.removeAll { $0.id == id }
        if events.count != before {
            broadcast()
        }
    }

    public func clear() {
        guard !events.isEmpty else { return }
        events.removeAll()
        broadcast()
    }

    public func snapshot() -> [NetworkEvent] {
        events
    }

    public func event(id: UUID) -> NetworkEvent? {
        events.first { $0.id == id }
    }

    public func stream() -> AsyncStream<[NetworkEvent]> {
        let id = UUID()
        let current = events
        return AsyncStream { continuation in
            continuation.yield(current)
            self.attach(id: id, continuation: continuation)
            continuation.onTermination = { @Sendable [weak self] _ in
                guard let self else { return }
                Task { await self.detach(id: id) }
            }
        }
    }

    private func attach(id: UUID, continuation: AsyncStream<[NetworkEvent]>.Continuation) {
        continuations[id] = continuation
    }

    private func detach(id: UUID) {
        continuations[id] = nil
    }

    private func evictIfNeeded() {
        if events.count > limit {
            events.removeFirst(events.count - limit)
        }
    }

    private func broadcast() {
        let snapshot = events
        for continuation in continuations.values {
            continuation.yield(snapshot)
        }
    }
}
