import Foundation

/// Actor-backed ring buffer for `LogEvent`s. Mirrors the shape of `EventStore` so the
/// console UI can use the same async-stream subscription pattern.
public actor LogEventStore {
    private var events: [LogEvent] = []
    private var limit: Int
    private var continuations: [UUID: AsyncStream<[LogEvent]>.Continuation] = [:]

    public init(limit: Int = 1_000) {
        self.limit = max(1, limit)
    }

    public func setLimit(_ newLimit: Int) {
        limit = max(1, newLimit)
        evictIfNeeded()
        broadcast()
    }

    public func append(_ event: LogEvent) {
        events.append(event)
        evictIfNeeded()
        broadcast()
    }

    public func clear() {
        guard !events.isEmpty else { return }
        events.removeAll()
        broadcast()
    }

    public func snapshot() -> [LogEvent] { events }

    public func stream() -> AsyncStream<[LogEvent]> {
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

    private func attach(id: UUID, continuation: AsyncStream<[LogEvent]>.Continuation) {
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
        let snap = events
        for continuation in continuations.values {
            continuation.yield(snap)
        }
    }
}
