import Foundation

/// On-disk representation of the captured event store across launches.
///
/// Held inside a `Shared(.fileStorage(_:))` reference by `PersistenceCoordinator`.
/// Sessions are stored in chronological order (oldest first); events are keyed by
/// session id to keep per-session reads O(1).
public struct PersistedEnvelope: Sendable, Equatable, Codable {
    public var sessions: [Session]
    public var events: [UUID: [NetworkEvent]]

    public init(sessions: [Session] = [], events: [UUID: [NetworkEvent]] = [:]) {
        self.sessions = sessions
        self.events = events
    }
}
