import Foundation

public struct NetworkMetrics: Sendable, Equatable, Hashable, Codable {
    public var duration: TimeInterval?
    public var requestStartDate: Date?
    public var requestEndDate: Date?
    public var responseStartDate: Date?
    public var responseEndDate: Date?
    public var requestBodyBytesBeforeEncoding: Int64?
    public var requestBodyBytesSent: Int64?
    public var requestHeaderBytesSent: Int64?
    public var responseBodyBytesAfterDecoding: Int64?
    public var responseBodyBytesReceived: Int64?
    public var responseHeaderBytesReceived: Int64?

    public init(
        duration: TimeInterval? = nil,
        requestStartDate: Date? = nil,
        requestEndDate: Date? = nil,
        responseStartDate: Date? = nil,
        responseEndDate: Date? = nil,
        requestBodyBytesBeforeEncoding: Int64? = nil,
        requestBodyBytesSent: Int64? = nil,
        requestHeaderBytesSent: Int64? = nil,
        responseBodyBytesAfterDecoding: Int64? = nil,
        responseBodyBytesReceived: Int64? = nil,
        responseHeaderBytesReceived: Int64? = nil
    ) {
        self.duration = duration
        self.requestStartDate = requestStartDate
        self.requestEndDate = requestEndDate
        self.responseStartDate = responseStartDate
        self.responseEndDate = responseEndDate
        self.requestBodyBytesBeforeEncoding = requestBodyBytesBeforeEncoding
        self.requestBodyBytesSent = requestBodyBytesSent
        self.requestHeaderBytesSent = requestHeaderBytesSent
        self.responseBodyBytesAfterDecoding = responseBodyBytesAfterDecoding
        self.responseBodyBytesReceived = responseBodyBytesReceived
        self.responseHeaderBytesReceived = responseHeaderBytesReceived
    }

    init(_ metrics: URLSessionTaskMetrics) {
        let first = metrics.transactionMetrics.first
        self.init(
            duration: metrics.taskInterval.duration,
            requestStartDate: first?.requestStartDate,
            requestEndDate: first?.requestEndDate,
            responseStartDate: first?.responseStartDate,
            responseEndDate: first?.responseEndDate,
            requestBodyBytesBeforeEncoding: first?.countOfRequestBodyBytesBeforeEncoding,
            requestBodyBytesSent: first?.countOfRequestBodyBytesSent,
            requestHeaderBytesSent: first?.countOfRequestHeaderBytesSent,
            responseBodyBytesAfterDecoding: first?.countOfResponseBodyBytesAfterDecoding,
            responseBodyBytesReceived: first?.countOfResponseBodyBytesReceived,
            responseHeaderBytesReceived: first?.countOfResponseHeaderBytesReceived
        )
    }
}
