import Foundation

public final class LoggingURLProtocol: URLProtocol, @unchecked Sendable {
    private enum Marker {
        static let key = "NetworkLoggerHandled"
    }

    private static let registry = LoggerRegistry()

    public static func activate(_ logger: NetworkLogger) {
        registry.set(logger)
    }

    public static func deactivate() {
        registry.set(nil)
    }

    /// Additional `URLProtocol` classes installed onto the internal session
    /// used to actually perform the network request. Test-only injection point.
    nonisolated(unsafe) public static var underlyingProtocolClasses: [AnyClass] = []

    private var internalSession: URLSession?
    private var internalTask: URLSessionDataTask?
    private var eventID = UUID()
    private var event: NetworkEvent?
    private var accumulator = BodyAccumulator(limit: 1_048_576)
    private var logger: NetworkLogger?

    public override class func canInit(with request: URLRequest) -> Bool {
        guard registry.current != nil else { return false }
        guard let scheme = request.url?.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return false }
        if Self.property(forKey: Marker.key, in: request) != nil { return false }
        switch request.cachePolicy {
        case .returnCacheDataDontLoad, .returnCacheDataElseLoad:
            return false
        default:
            return true
        }
    }

    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    public override class func requestIsCacheEquivalent(_ a: URLRequest, to b: URLRequest) -> Bool {
        false
    }

    public override func startLoading() {
        guard let logger = Self.registry.current else {
            client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
            return
        }
        self.logger = logger
        self.accumulator = BodyAccumulator(limit: 1_048_576)

        let mutable = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        Self.setProperty(true, forKey: Marker.key, in: mutable)

        let teeBuffer = StreamTeeBuffer()
        if let stream = mutable.httpBodyStream {
            let tee = BodyStreamTee(upstream: stream, limit: 1_048_576) { chunk in
                teeBuffer.append(chunk)
            }
            mutable.httpBodyStream = tee
        }

        var snapshot = RequestSnapshotBuilder.make(from: request)
        if snapshot.body == nil, let captured = teeBuffer.data(), !captured.isEmpty {
            snapshot = updating(snapshot, with: captured, contentType: snapshot.headers["Content-Type"])
        }
        let newEvent = NetworkEvent(id: eventID, request: snapshot)
        self.event = newEvent

        Task { await logger.record(newEvent) }

        let internalConfig = URLSessionConfiguration.ephemeral
        if !Self.underlyingProtocolClasses.isEmpty {
            var classes = internalConfig.protocolClasses ?? []
            classes.insert(contentsOf: Self.underlyingProtocolClasses, at: 0)
            internalConfig.protocolClasses = classes
        }
        let session = URLSession(configuration: internalConfig, delegate: self, delegateQueue: nil)
        self.internalSession = session
        let task = session.dataTask(with: mutable as URLRequest)
        self.internalTask = task
        task.resume()

        self.teeBuffer = teeBuffer
    }

    public override func stopLoading() {
        if var event = self.event, event.state == .inFlight {
            event.state = .cancelled
            self.event = event
            if let logger {
                Task { await logger.record(event) }
            }
        }
        internalTask?.cancel()
        internalSession?.invalidateAndCancel()
        internalSession = nil
        internalTask = nil
    }

    private var teeBuffer: StreamTeeBuffer?

    fileprivate func updating(
        _ snapshot: NetworkRequestSnapshot,
        with data: Data,
        contentType: String?
    ) -> NetworkRequestSnapshot {
        NetworkRequestSnapshot(
            url: snapshot.url,
            httpMethod: snapshot.httpMethod,
            headers: snapshot.headers,
            body: BodyData(
                data: data,
                originalSize: Int64(data.count),
                truncated: false,
                contentType: contentType
            ),
            credentials: snapshot.credentials,
            cookies: snapshot.cookies
        )
    }
}

extension LoggingURLProtocol: URLSessionDataDelegate {
    public func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @Sendable @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        let policy: URLCache.StoragePolicy = .notAllowed
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: policy)

        if var event = self.event, let http = response as? HTTPURLResponse {
            if var existing = event.response {
                existing.statusCode = http.statusCode
                existing.headers = http.allHeaderFields.reduce(into: [String: String]()) { result, pair in
                    if let key = pair.key as? String {
                        result[key] = "\(pair.value)"
                    }
                }
                existing.mimeType = http.mimeType
                existing.textEncodingName = http.textEncodingName
                event.response = existing
            } else {
                event.response = NetworkResponseSnapshot(httpResponse: http)
            }
            self.event = event
            if let logger {
                Task { await logger.record(event) }
            }
        }
        completionHandler(.allow)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        client?.urlProtocol(self, didLoad: data)

        accumulator.append(data)
        if var event = self.event {
            var response = event.response ?? NetworkResponseSnapshot(statusCode: 0)
            response.body = accumulator.body(contentType: response.headers["Content-Type"] ?? response.mimeType)
            event.response = response
            self.event = event
            if let logger {
                Task { await logger.record(event) }
            }
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if var event = self.event {
            if let teeData = teeBuffer?.data(), !teeData.isEmpty, event.request.body == nil {
                event.request = updating(event.request, with: teeData, contentType: event.request.headers["Content-Type"])
            }
            if let error {
                let networkError = NetworkError(error)
                event.error = networkError
                event.state = networkError.code == NSURLErrorCancelled ? .cancelled : .failed
            } else {
                event.state = .completed
            }
            self.event = event
            if let logger {
                Task { await logger.record(event) }
            }
        }

        if let error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        if var event = self.event {
            let captured = NetworkMetrics(metrics)
            event.metrics = captured
            self.event = event
            if let logger {
                Task { await logger.record(event) }
            }
        }
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @Sendable @escaping (URLRequest?) -> Void
    ) {
        client?.urlProtocol(self, wasRedirectedTo: request, redirectResponse: response)
        completionHandler(nil)
    }

    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @Sendable @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        client?.urlProtocol(self, didReceive: challenge)
        completionHandler(.performDefaultHandling, nil)
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @Sendable @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        client?.urlProtocol(self, didReceive: challenge)
        completionHandler(.performDefaultHandling, nil)
    }
}

private final class LoggerRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: NetworkLogger?

    func set(_ logger: NetworkLogger?) {
        lock.lock()
        stored = logger
        lock.unlock()
    }

    var current: NetworkLogger? {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }
}

final class StreamTeeBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()

    func append(_ chunk: Data) {
        lock.lock()
        buffer.append(chunk)
        lock.unlock()
    }

    func data() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return buffer.isEmpty ? nil : buffer
    }
}

