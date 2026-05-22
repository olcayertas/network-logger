import Foundation

/// On-disk shape for the recent-searches store.
///
/// Phase 2 ships with plain search strings only. Phase 3 will add token-set snapshots
/// (`filters`) once structured search tokens land.
public struct RecentSearches: Sendable, Equatable, Codable {
    public var searches: [String]

    public init(searches: [String] = []) {
        self.searches = searches
    }
}
