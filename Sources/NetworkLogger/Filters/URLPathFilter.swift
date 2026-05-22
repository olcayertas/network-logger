import Foundation

/// Matches when `event.request.url.path` contains `needle`.
///
/// Distinct from `URLSubstringFilter`, which matches anywhere in the absolute URL
/// (including scheme, host, and query). `URLPathFilter` ignores those.
public struct URLPathFilter: EventFilter {
    public let needle: String
    public let caseInsensitive: Bool

    public init(_ needle: String, caseInsensitive: Bool = true) {
        self.needle = needle
        self.caseInsensitive = caseInsensitive
    }

    public func includes(_ event: NetworkEvent) -> Bool {
        guard !needle.isEmpty else { return true }
        return event.request.url.path.range(
            of: needle,
            options: caseInsensitive ? .caseInsensitive : []
        ) != nil
    }
}
