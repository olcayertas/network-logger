import Foundation

public struct MethodFilter: EventFilter {
    public let methods: Set<String>

    public init(_ methods: Set<String>) {
        self.methods = Set(methods.map { $0.uppercased() })
    }

    public init(_ methods: String...) {
        self.init(Set(methods))
    }

    public func includes(_ event: NetworkEvent) -> Bool {
        methods.contains(event.request.httpMethod.uppercased())
    }
}
