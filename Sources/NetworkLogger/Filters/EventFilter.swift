import Foundation

public protocol EventFilter: Sendable {
    func includes(_ event: NetworkEvent) -> Bool
}

public extension EventFilter {
    func callAsFunction(_ event: NetworkEvent) -> Bool {
        includes(event)
    }
}

public extension Array where Element == NetworkEvent {
    func filtered(by filter: any EventFilter) -> [NetworkEvent] {
        self.filter { filter.includes($0) }
    }
}
