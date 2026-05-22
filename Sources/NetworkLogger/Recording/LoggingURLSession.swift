import Foundation

/// A pre-wired `URLSession` whose delegate is `LoggingURLSessionDelegate` and
/// whose `data(for:)` method routes every request through the logger.
///
/// Usage:
///
/// ```swift
/// let session = logger.makeLoggingURLSession()
/// let (data, response) = try await session.data(for: request)
/// ```
///
/// This is the replacement for the `LoggingSessionBox` / `LoggingResultSink`
/// glue that consumers used to write themselves. It does the work the network
/// inspector needs to capture full request/response bodies on iOS 26+ where
/// the async convenience APIs (`URLSession.data(for:delegate:)`) no longer
/// fire `URLSessionDataDelegate` callbacks to the per-task delegate.
///
/// ## Why this is an actor
///
/// The underlying `URLSession` and its `TaskResultSink` are created lazily on
/// the first `data(for:)` call. The actor's serial executor guarantees the
/// lazy-init check-then-create is not raced (with one allocation-only
/// reentrancy caveat noted in `sessionAndSink()` — never a correctness issue).
/// Once the cache is populated, callers do not suspend on the actor's executor
/// for steady-state requests; they suspend on the URLSessionTask completing.
public actor LoggingURLSession {

    private let logger: NetworkLogger
    private let bodyCaptureLimit: Int
    private var cached: (session: URLSession, sink: TaskResultSink)?

    public init(logger: NetworkLogger, bodyCaptureLimit: Int = 1_048_576) {
        self.logger = logger
        self.bodyCaptureLimit = bodyCaptureLimit
    }

    /// Performs `request` through the logger-wired session and returns the
    /// raw `(Data, URLResponse)` pair, exactly as `URLSession.data(for:)` does.
    ///
    /// Cancellation is forwarded to the underlying `URLSessionDataTask`.
    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let (session, sink) = await sessionAndSink()
        return try await sink.run(request, on: session)
    }

    /// Returns the shared session+sink, creating them on the first call.
    ///
    /// Reentrancy: `makeSessionDelegate(forwardingTo:)` is `async` (it reads
    /// the logger's configuration actor), so this method has a suspension
    /// point. Two concurrent first-callers can both see `cached == nil` and
    /// both build a session. The second to write wins; the first session is
    /// dropped before any request flows through it — no requests are lost, at
    /// the cost of one wasted `URLSession` allocation on startup contention.
    private func sessionAndSink() async -> (URLSession, TaskResultSink) {
        if let cached { return (cached.session, cached.sink) }

        let sink = TaskResultSink(bodyCaptureLimit: bodyCaptureLimit)
        let delegate = await logger.makeSessionDelegate(forwardingTo: sink, retainForwardee: true)
        let session = URLSession(
            configuration: .default,
            delegate: delegate,
            delegateQueue: nil
        )
        cached = (session, sink)
        return (session, sink)
    }
}

public extension NetworkLogger {
    /// Returns a `LoggingURLSession` that routes requests through this logger.
    ///
    /// The actor is constructed synchronously; the underlying `URLSession` is
    /// built lazily on the first `data(for:)` call.
    func makeLoggingURLSession(bodyCaptureLimit: Int = 1_048_576) -> LoggingURLSession {
        LoggingURLSession(logger: self, bodyCaptureLimit: bodyCaptureLimit)
    }
}
