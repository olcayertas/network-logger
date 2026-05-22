import Foundation
import Sharing

/// Persists the user's recent search strings via swift-sharing's file storage.
///
/// MRU semantics: the most recently committed search lands at index 0; duplicates are
/// re-ordered rather than appended; the list is capped at `limit` (default 10).
public final class RecentSearchesStore: Sendable {
    public static let defaultLimit = 10

    /// Underlying shared reference. SwiftUI views observe via `@SharedReader(store.shared)`.
    public let shared: Shared<RecentSearches>
    private let limit: Int

    public init(directory: URL, limit: Int = RecentSearchesStore.defaultLimit) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("recent-searches.json")
        self.shared = Shared(wrappedValue: RecentSearches(), .fileStorage(url))
        self.limit = max(1, limit)
    }

    public func snapshot() -> [String] {
        shared.wrappedValue.searches
    }

    public func record(_ search: String) {
        let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        shared.withLock { current in
            current.searches.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
            current.searches.insert(trimmed, at: 0)
            if current.searches.count > limit {
                current.searches.removeLast(current.searches.count - limit)
            }
        }
    }

    public func remove(_ search: String) {
        shared.withLock { current in
            current.searches.removeAll { $0 == search }
        }
    }

    public func clear() {
        shared.withLock { $0.searches.removeAll() }
    }
}
