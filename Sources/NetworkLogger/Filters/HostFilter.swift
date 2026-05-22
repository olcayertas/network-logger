import Foundation

public struct HostFilter: EventFilter {
    private let predicate: @Sendable (String) -> Bool

    public init(allowing hosts: [String]) {
        let allowed = hosts.map { $0.lowercased() }
        self.predicate = { host in
            allowed.contains { host.lowercased().hasSuffix($0) }
        }
    }

    public init(blocking hosts: [String]) {
        let blocked = hosts.map { $0.lowercased() }
        self.predicate = { host in
            !blocked.contains { host.lowercased().hasSuffix($0) }
        }
    }

    public init(_ predicate: @escaping @Sendable (String) -> Bool) {
        self.predicate = predicate
    }

    public func includes(_ event: NetworkEvent) -> Bool {
        guard let host = event.request.host else { return false }
        return predicate(host)
    }
}
