import Foundation

public struct StatusCodeRangeFilter: EventFilter {
    public let range: ClosedRange<Int>

    public init(_ range: ClosedRange<Int>) {
        self.range = range
    }

    public func includes(_ event: NetworkEvent) -> Bool {
        guard let code = event.response?.statusCode else { return false }
        return range.contains(code)
    }
}

public extension StatusCodeRangeFilter {
    static let informational = StatusCodeRangeFilter(100...199)
    static let success = StatusCodeRangeFilter(200...299)
    static let redirection = StatusCodeRangeFilter(300...399)
    static let clientError = StatusCodeRangeFilter(400...499)
    static let serverError = StatusCodeRangeFilter(500...599)
}
