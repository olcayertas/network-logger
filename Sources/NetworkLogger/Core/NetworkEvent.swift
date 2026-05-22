import Foundation

public struct NetworkEvent: Sendable, Identifiable, Equatable, Hashable, Codable {
    public enum State: String, Sendable, Equatable, Codable {
        case inFlight
        case completed
        case failed
        case cancelled
    }

    public let id: UUID
    public let startDate: Date
    public var request: NetworkRequestSnapshot
    public var response: NetworkResponseSnapshot?
    public var metrics: NetworkMetrics
    public var error: NetworkError?
    public var state: State

    public init(
        id: UUID = UUID(),
        startDate: Date = Date(),
        request: NetworkRequestSnapshot,
        response: NetworkResponseSnapshot? = nil,
        metrics: NetworkMetrics = .init(),
        error: NetworkError? = nil,
        state: State = .inFlight
    ) {
        self.id = id
        self.startDate = startDate
        self.request = request
        self.response = response
        self.metrics = metrics
        self.error = error
        self.state = state
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: NetworkEvent, rhs: NetworkEvent) -> Bool {
        lhs.id == rhs.id
            && lhs.state == rhs.state
            && lhs.request == rhs.request
            && lhs.response == rhs.response
            && lhs.metrics == rhs.metrics
            && lhs.error == rhs.error
    }
}

public extension NetworkEvent {
    var isSuccess: Bool {
        guard let response else { return false }
        return (200..<300).contains(response.statusCode)
    }

    var isClientError: Bool {
        guard let response else { return false }
        return (400..<500).contains(response.statusCode)
    }

    var isServerError: Bool {
        guard let response else { return false }
        return (500..<600).contains(response.statusCode)
    }
}
