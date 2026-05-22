#if canImport(SwiftUI)
import Foundation
import Perception

@MainActor
@Perceptible
public final class EventListModel {
    public private(set) var events: [NetworkEvent] = []
    public var searchText: String = ""
    public var statusCodeFilter: StatusCodeRangeFilter?
    public var methodFilter: MethodFilter?
    public var dateRange: ClosedRange<Date>?

    @PerceptionIgnored
    public let logger: NetworkLogger?

    @PerceptionIgnored
    private var streamTask: Task<Void, Never>?

    public init(logger: NetworkLogger) {
        self.logger = logger
    }

    /// Read-only init for browsing a past, persisted session.
    public init(snapshot: [NetworkEvent]) {
        self.logger = nil
        self.events = snapshot
    }

    public var isReadOnly: Bool { logger == nil }

    public func start() {
        guard let logger else { return }
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            let stream = await logger.eventStream()
            for await snapshot in stream {
                guard let self else { break }
                self.events = snapshot
            }
        }
        Task { [weak self] in
            guard let self else { return }
            let config = await logger.configuration()
            if self.searchText.isEmpty, let defaultFilter = config.defaultFilter {
                self.searchText = defaultFilter
            }
        }
    }

    public func stop() {
        streamTask?.cancel()
        streamTask = nil
    }

    public func clear() {
        guard let logger else { return }
        Task { await logger.clear() }
    }

    public var parsedSearch: ParsedSearch {
        SearchTokenParser.parse(searchText)
    }

    public var filtered: [NetworkEvent] {
        var filter: any EventFilter = AlwaysFilter()
        var composites: [any EventFilter] = []
        let parsed = parsedSearch
        for token in parsed.tokens {
            composites.append(token.filter)
        }
        if !parsed.freeText.isEmpty {
            composites.append(URLSubstringFilter(parsed.freeText))
        }
        if let statusCodeFilter {
            composites.append(statusCodeFilter)
        }
        if let methodFilter {
            composites.append(methodFilter)
        }
        if let dateRange {
            composites.append(DateRangeFilter(dateRange))
        }
        if !composites.isEmpty {
            filter = CompositeFilter(composites)
        }
        return events.filter { filter.includes($0) }.sorted { $0.startDate > $1.startDate }
    }

    /// Removes a parsed token's raw spelling from the search text. The chip UI calls
    /// this when the user taps the chip's close affordance.
    public func remove(_ token: SearchToken) {
        let raw = token.rawSpelling
        let pieces = searchText.split(whereSeparator: \.isWhitespace).filter { String($0) != raw }
        searchText = pieces.joined(separator: " ")
    }
}

private struct AlwaysFilter: EventFilter {
    func includes(_ event: NetworkEvent) -> Bool { true }
}
#endif
