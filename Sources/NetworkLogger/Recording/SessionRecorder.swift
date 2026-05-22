import Foundation

actor SessionRecorder {
    private let logger: NetworkLogger
    private let bodyCaptureLimit: Int
    private var events: [Int: NetworkEvent] = [:]
    private var pendingBodies: [Int: BodyAccumulator] = [:]

    init(logger: NetworkLogger, bodyCaptureLimit: Int) {
        self.logger = logger
        self.bodyCaptureLimit = max(0, bodyCaptureLimit)
    }

    func start(taskID: Int, request: NetworkRequestSnapshot) async {
        guard events[taskID] == nil else { return }
        let event = NetworkEvent(request: request)
        events[taskID] = event
        await logger.record(event)
    }

    func ensureStarted(taskID: Int, request: NetworkRequestSnapshot) async {
        await start(taskID: taskID, request: request)
    }

    func receivedResponse(taskID: Int, response: HTTPURLResponse) async {
        guard var event = events[taskID] else { return }
        let headers = response.allHeaderFields.reduce(into: [String: String]()) { result, pair in
            if let key = pair.key as? String {
                result[key] = "\(pair.value)"
            }
        }
        if var existing = event.response {
            existing.statusCode = response.statusCode
            existing.headers = headers
            existing.mimeType = response.mimeType
            existing.textEncodingName = response.textEncodingName
            event.response = existing
        } else {
            event.response = NetworkResponseSnapshot(httpResponse: response)
        }
        events[taskID] = event
        await logger.record(event)
    }

    func receivedData(taskID: Int, data: Data) async {
        var accumulator = pendingBodies[taskID] ?? BodyAccumulator(limit: bodyCaptureLimit)
        accumulator.append(data)
        pendingBodies[taskID] = accumulator

        guard var event = events[taskID] else { return }
        var response = event.response ?? NetworkResponseSnapshot(statusCode: 0)
        let contentType = response.headers["Content-Type"] ?? response.mimeType
        response.body = accumulator.body(contentType: contentType)
        event.response = response
        events[taskID] = event
        await logger.record(event)
    }

    func sentBodyData(taskID: Int, totalBytesSent: Int64, totalExpectedToSend: Int64) async {
        guard var event = events[taskID] else { return }
        event.metrics.requestBodyBytesSent = totalBytesSent
        if totalExpectedToSend > 0 {
            event.metrics.requestBodyBytesBeforeEncoding = totalExpectedToSend
        }
        events[taskID] = event
        await logger.record(event)
    }

    func collectedMetrics(taskID: Int, metrics: URLSessionTaskMetrics) async {
        guard var event = events[taskID] else { return }
        let captured = NetworkMetrics(metrics)
        event.metrics.duration = captured.duration ?? event.metrics.duration
        event.metrics.requestStartDate = captured.requestStartDate ?? event.metrics.requestStartDate
        event.metrics.requestEndDate = captured.requestEndDate ?? event.metrics.requestEndDate
        event.metrics.responseStartDate = captured.responseStartDate ?? event.metrics.responseStartDate
        event.metrics.responseEndDate = captured.responseEndDate ?? event.metrics.responseEndDate
        event.metrics.requestBodyBytesBeforeEncoding = captured.requestBodyBytesBeforeEncoding ?? event.metrics.requestBodyBytesBeforeEncoding
        event.metrics.requestBodyBytesSent = captured.requestBodyBytesSent ?? event.metrics.requestBodyBytesSent
        event.metrics.requestHeaderBytesSent = captured.requestHeaderBytesSent ?? event.metrics.requestHeaderBytesSent
        event.metrics.responseBodyBytesAfterDecoding = captured.responseBodyBytesAfterDecoding ?? event.metrics.responseBodyBytesAfterDecoding
        event.metrics.responseBodyBytesReceived = captured.responseBodyBytesReceived ?? event.metrics.responseBodyBytesReceived
        event.metrics.responseHeaderBytesReceived = captured.responseHeaderBytesReceived ?? event.metrics.responseHeaderBytesReceived
        events[taskID] = event
        await logger.record(event)
    }

    func finished(taskID: Int, error: Error?) async {
        guard var event = events[taskID] else { return }
        if let error {
            let networkError = NetworkError(error)
            event.error = networkError
            event.state = networkError.code == NSURLErrorCancelled ? .cancelled : .failed
        } else {
            event.state = .completed
        }
        events[taskID] = event
        pendingBodies[taskID] = nil
        await logger.record(event)
        events.removeValue(forKey: taskID)
    }

    func updateRequest(taskID: Int, request: NetworkRequestSnapshot) async {
        guard var event = events[taskID] else { return }
        event.request = request
        events[taskID] = event
        await logger.record(event)
    }
}

