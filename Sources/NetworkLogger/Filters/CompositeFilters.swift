import Foundation

public struct CompositeFilter: EventFilter {
    public let filters: [any EventFilter]

    public init(_ filters: [any EventFilter]) {
        self.filters = filters
    }

    public init(_ filters: (any EventFilter)...) {
        self.filters = filters
    }

    public func includes(_ event: NetworkEvent) -> Bool {
        filters.allSatisfy { $0.includes(event) }
    }
}

public struct AnyOfFilter: EventFilter {
    public let filters: [any EventFilter]

    public init(_ filters: [any EventFilter]) {
        self.filters = filters
    }

    public init(_ filters: (any EventFilter)...) {
        self.filters = filters
    }

    public func includes(_ event: NetworkEvent) -> Bool {
        filters.contains { $0.includes(event) }
    }
}

public struct NotFilter: EventFilter {
    public let base: any EventFilter

    public init(_ base: any EventFilter) {
        self.base = base
    }

    public func includes(_ event: NetworkEvent) -> Bool {
        !base.includes(event)
    }
}
