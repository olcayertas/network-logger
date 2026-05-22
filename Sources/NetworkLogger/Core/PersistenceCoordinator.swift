import Foundation
import Sharing

/// File-backed persistence for captured network events.
///
/// Wraps a `Shared(.fileStorage(_:))` envelope containing every retained session and its
/// events. On init, a new current-session entry is appended and retention is applied
/// (`maxSessions` newest are kept; anything older than `maxAgeDays` is pruned).
///
/// The coordinator is `Sendable` because `Shared` performs its own internal locking and
/// coalesces writes. Callers don't need to await anything; `record(_:)` is fire-and-forget.
public final class PersistenceCoordinator: Sendable {
    public let currentSessionID: UUID
    private let envelope: Shared<PersistedEnvelope>

    public init(directory: URL, maxSessions: Int, maxAgeDays: Int, now: Date = Date()) {
        let storeURL = directory.appendingPathComponent("network-logger-events.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let envelope = Shared(wrappedValue: PersistedEnvelope(), .fileStorage(storeURL))
        self.envelope = envelope

        let newID = UUID()
        self.currentSessionID = newID

        envelope.withLock { env in
            // Drop sessions older than maxAgeDays.
            if maxAgeDays > 0 {
                let cutoff = now.addingTimeInterval(-Double(maxAgeDays) * 86_400)
                let aged = env.sessions.filter { $0.startedAt < cutoff }.map(\.id)
                if !aged.isEmpty {
                    env.sessions.removeAll { aged.contains($0.id) }
                    for id in aged { env.events.removeValue(forKey: id) }
                }
            }
            // Append the new current session.
            env.sessions.append(Session(id: newID, startedAt: now))
            // Enforce maxSessions (newest wins).
            if maxSessions > 0, env.sessions.count > maxSessions {
                let excess = env.sessions.count - maxSessions
                let droppedIDs = env.sessions.prefix(excess).map(\.id)
                env.sessions.removeFirst(excess)
                for id in droppedIDs { env.events.removeValue(forKey: id) }
            }
        }
    }

    public func record(_ event: NetworkEvent) {
        envelope.withLock { env in
            var list = env.events[currentSessionID] ?? []
            if let index = list.firstIndex(where: { $0.id == event.id }) {
                list[index] = event
            } else {
                list.append(event)
            }
            env.events[currentSessionID] = list
        }
    }

    public func clearCurrent() {
        envelope.withLock { env in
            env.events[currentSessionID] = []
        }
    }

    public func deleteSession(id: UUID) {
        envelope.withLock { env in
            env.sessions.removeAll { $0.id == id }
            env.events.removeValue(forKey: id)
        }
    }

    public func sessions() -> [Session] {
        envelope.wrappedValue.sessions
    }

    public func events(for sessionID: UUID) -> [NetworkEvent] {
        envelope.wrappedValue.events[sessionID] ?? []
    }
}
