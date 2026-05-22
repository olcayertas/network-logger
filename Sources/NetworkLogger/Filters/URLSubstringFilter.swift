import Foundation

public struct URLSubstringFilter: EventFilter {
    public let needle: String
    public let caseInsensitive: Bool

    public init(_ needle: String, caseInsensitive: Bool = true) {
        self.needle = needle
        self.caseInsensitive = caseInsensitive
    }

    public func includes(_ event: NetworkEvent) -> Bool {
        guard !needle.isEmpty else { return true }
        let haystack = event.request.url.absoluteString
        return haystack.range(
            of: needle,
            options: caseInsensitive ? .caseInsensitive : []
        ) != nil
    }
}
