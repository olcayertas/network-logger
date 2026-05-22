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

    @PerceptionIgnored
    private let logger: NetworkLogger

    @PerceptionIgnored
    private var streamTask: Task<Void, Never>?

    public init(logger: NetworkLogger) {
        self.logger = logger
    }

    public func start() {
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            guard let stream = await self?.logger.eventStream() else { return }
            for await snapshot in stream {
                guard let self else { break }
                self.events = snapshot
            }
        }
        Task { [weak self] in
            guard let self else { return }
            let config = await self.logger.configuration()
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
        Task { [weak self] in
            await self?.logger.clear()
        }
    }

    public var filtered: [NetworkEvent] {
        var filter: any EventFilter = AlwaysFilter()
        var composites: [any EventFilter] = []
        if !searchText.isEmpty {
            composites.append(URLSubstringFilter(searchText))
        }
        if let statusCodeFilter {
            composites.append(statusCodeFilter)
        }
        if let methodFilter {
            composites.append(methodFilter)
        }
        if !composites.isEmpty {
            filter = CompositeFilter(composites)
        }
        return events.filter { filter.includes($0) }.sorted { $0.startDate > $1.startDate }
    }
}

private struct AlwaysFilter: EventFilter {
    func includes(_ event: NetworkEvent) -> Bool { true }
}
#endif
