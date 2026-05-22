import Foundation

/// A logical grouping of captured events.
///
/// Typical use creates one `Session` per `NetworkLogger` initialisation — i.e. one per app
/// launch. With file-backed persistence enabled, past sessions can be browsed from
/// `SessionListView`.
public struct Session: Sendable, Identifiable, Equatable, Hashable, Codable {
    public let id: UUID
    public let startedAt: Date
    public var label: String?

    public init(id: UUID = UUID(), startedAt: Date = Date(), label: String? = nil) {
        self.id = id
        self.startedAt = startedAt
        self.label = label
    }
}
