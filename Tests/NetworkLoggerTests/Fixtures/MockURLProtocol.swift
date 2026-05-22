import Foundation

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static let registry = HandlerRegistry()

    override class func canInit(with request: URLRequest) -> Bool {
        registry.handler(for: request) != nil
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.registry.handler(for: request) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    @discardableResult
    static func install(
        host: String,
        _ handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data?)
    ) -> HandlerHandle {
        registry.set(host: host, handler: handler)
        return HandlerHandle(host: host)
    }

    static func reset(host: String) {
        registry.remove(host: host)
    }

    static func resetAll() {
        registry.removeAll()
    }
}

struct HandlerHandle {
    let host: String

    func reset() {
        MockURLProtocol.reset(host: host)
    }
}

final class HandlerRegistry: @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data?)

    private let lock = NSLock()
    private var handlers: [String: Handler] = [:]

    func handler(for request: URLRequest) -> Handler? {
        guard let host = request.url?.host else { return nil }
        lock.lock(); defer { lock.unlock() }
        return handlers[host]
    }

    func set(host: String, handler: @escaping Handler) {
        lock.lock(); defer { lock.unlock() }
        handlers[host] = handler
    }

    func remove(host: String) {
        lock.lock(); defer { lock.unlock() }
        handlers.removeValue(forKey: host)
    }

    func removeAll() {
        lock.lock(); defer { lock.unlock() }
        handlers.removeAll()
    }
}

extension URLSessionConfiguration {
    static func mockEphemeral() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return config
    }
}
