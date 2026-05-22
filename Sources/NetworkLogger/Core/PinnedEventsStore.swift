import Foundation
import Sharing

/// Persists the set of pinned event ids via swift-sharing's file storage.
///
/// Pin state lives outside `NetworkEvent` so the event record stays a pure capture
/// snapshot and pin state can be toggled without touching the event store. Pins survive
/// app launches; sessions that get pruned leave their ids as harmless orphan entries
/// (the UI just won't find an event to render).
public final class PinnedEventsStore: Sendable {
    /// Underlying shared reference. SwiftUI views observe via `@SharedReader(store.shared)`.
    public let shared: Shared<Set<UUID>>

    public init(directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("pinned-events.json")
        self.shared = Shared(wrappedValue: Set<UUID>(), .fileStorage(url))
    }

    public func snapshot() -> Set<UUID> {
        shared.wrappedValue
    }

    public func isPinned(_ id: UUID) -> Bool {
        shared.wrappedValue.contains(id)
    }

    public func pin(_ id: UUID) {
        shared.withLock { _ = $0.insert(id) }
    }

    public func unpin(_ id: UUID) {
        shared.withLock { _ = $0.remove(id) }
    }

    public func togglePin(_ id: UUID) {
        shared.withLock { set in
            if set.contains(id) { set.remove(id) } else { set.insert(id) }
        }
    }

    public func clear() {
        shared.withLock { $0.removeAll() }
    }
}
