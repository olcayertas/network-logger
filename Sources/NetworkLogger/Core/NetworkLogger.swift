import Foundation

public final class NetworkLogger: Sendable {
    public let store: EventStore
    public let persistence: PersistenceCoordinator?
    private let configStore: ConfigurationStore

    public init(configuration: NetworkLoggerConfiguration = .init()) {
        self.store = EventStore(limit: configuration.limit)
        switch configuration.persistence {
        case .inMemory:
            self.persistence = nil
        case let .fileBacked(directory, maxSessions, maxAgeDays):
            self.persistence = PersistenceCoordinator(
                directory: directory,
                maxSessions: maxSessions,
                maxAgeDays: maxAgeDays
            )
        }
        self.configStore = ConfigurationStore(configuration)
        if let persistence {
            Task { [store, persistence] in
                let initial = await store.snapshot()
                for event in initial { persistence.record(event) }
            }
        }
    }

    /// The id of the session whose events are flowing through this logger right now.
    /// `nil` when persistence is disabled.
    public var currentSessionID: UUID? { persistence?.currentSessionID }

    public func configuration() async -> NetworkLoggerConfiguration {
        await configStore.current
    }

    public func replaceConfiguration(_ configuration: NetworkLoggerConfiguration) async {
        await configStore.replace(with: configuration)
        await store.setLimit(configuration.limit)
    }

    public func setLimit(_ limit: Int) async {
        await configStore.mutate { $0.limit = limit }
        await store.setLimit(limit)
    }

    public func setIgnoredHosts(_ hosts: [String]) async {
        await configStore.mutate { $0.ignoredHosts = hosts }
    }

    public func setDefaultFilter(_ filter: String?) async {
        await configStore.mutate { $0.defaultFilter = filter }
    }

    public func record(_ event: NetworkEvent) async {
        let config = await configStore.current
        guard !config.shouldIgnore(host: event.request.host) else { return }
        let sanitized = sanitize(event, with: config)
        await store.upsert(sanitized)
        persistence?.record(sanitized)
    }

    public func clear() async {
        await store.clear()
        persistence?.clearCurrent()
    }

    public func snapshot() async -> [NetworkEvent] {
        await store.snapshot()
    }

    public func eventStream() async -> AsyncStream<[NetworkEvent]> {
        await store.stream()
    }

    public func makeSessionDelegate(
        forwardingTo delegate: (any URLSessionDelegate)? = nil,
        retainForwardee: Bool = true
    ) async -> LoggingURLSessionDelegate {
        let config = await configStore.current
        return LoggingURLSessionDelegate(
            logger: self,
            forwardingTo: delegate,
            retainForwardee: retainForwardee,
            bodyCaptureLimit: config.bodyCaptureLimit
        )
    }

    public var urlProtocolClass: AnyClass {
        LoggingURLProtocol.self
    }

    public func attach(to configuration: URLSessionConfiguration) {
        LoggingURLProtocol.activate(self)
        var classes = configuration.protocolClasses ?? []
        if !classes.contains(where: { $0 == LoggingURLProtocol.self }) {
            classes.insert(LoggingURLProtocol.self, at: 0)
        }
        configuration.protocolClasses = classes
    }

    public func detach(from configuration: URLSessionConfiguration) {
        var classes = configuration.protocolClasses ?? []
        classes.removeAll { $0 == LoggingURLProtocol.self }
        configuration.protocolClasses = classes
    }

    func sanitize(_ event: NetworkEvent, with config: NetworkLoggerConfiguration) -> NetworkEvent {
        var copy = event
        copy.request = NetworkRequestSnapshot(
            url: copy.request.url,
            httpMethod: copy.request.httpMethod,
            headers: config.headerRedactor(copy.request.headers),
            body: copy.request.body,
            credentials: copy.request.credentials,
            cookies: copy.request.cookies
        )
        if var response = copy.response {
            let redactedHeaders = config.headerRedactor(response.headers)
            let transformedBody: BodyData? = response.body.map { body in
                BodyData(
                    data: config.responseTransformer(body.data, copy.request),
                    originalSize: body.originalSize,
                    truncated: body.truncated,
                    contentType: body.contentType
                )
            }
            response = NetworkResponseSnapshot(
                statusCode: response.statusCode,
                headers: redactedHeaders,
                body: transformedBody,
                mimeType: response.mimeType,
                textEncodingName: response.textEncodingName
            )
            copy.response = response
        }
        return copy
    }
}
