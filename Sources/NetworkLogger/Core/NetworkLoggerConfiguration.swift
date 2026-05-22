import Foundation

public struct NetworkLoggerConfiguration: Sendable {
    public var limit: Int
    public var ignoredHosts: [String]
    public var defaultFilter: String?
    public var bodyCaptureLimit: Int
    public var persistence: Persistence
    public var headerRedactor: @Sendable (_ headers: [String: String]) -> [String: String]
    public var responseTransformer: @Sendable (_ body: Data, _ request: NetworkRequestSnapshot) -> Data

    public init(
        limit: Int = 500,
        ignoredHosts: [String] = [],
        defaultFilter: String? = nil,
        bodyCaptureLimit: Int = 1_048_576,
        persistence: Persistence = .inMemory,
        headerRedactor: @escaping @Sendable ([String: String]) -> [String: String] = Self.defaultHeaderRedactor,
        responseTransformer: @escaping @Sendable (Data, NetworkRequestSnapshot) -> Data = { data, _ in data }
    ) {
        self.limit = max(1, limit)
        self.ignoredHosts = ignoredHosts
        self.defaultFilter = defaultFilter
        self.bodyCaptureLimit = max(0, bodyCaptureLimit)
        self.persistence = persistence
        self.headerRedactor = headerRedactor
        self.responseTransformer = responseTransformer
    }

    /// Where captured events live.
    ///
    /// - `inMemory`: events live only in the current-process `EventStore`. Default.
    /// - `fileBacked`: events are also written to a JSON file under `directory` via
    ///   [pointfreeco/swift-sharing](https://github.com/pointfreeco/swift-sharing). On
    ///   next launch, past sessions are browsable from `SessionListView`. Retention is
    ///   bounded by `maxSessions` (newest wins) and `maxAgeDays`.
    public enum Persistence: Sendable {
        case inMemory
        case fileBacked(directory: URL, maxSessions: Int = 5, maxAgeDays: Int = 14)

        /// Default file-backed config writing under Application Support.
        public static var fileBackedDefault: Persistence {
            let base = (try? FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )) ?? FileManager.default.temporaryDirectory
            return .fileBacked(directory: base.appendingPathComponent("NetworkLogger", isDirectory: true))
        }
    }

    public static let defaultHeaderRedactor: @Sendable ([String: String]) -> [String: String] = { headers in
        let sensitive: Set<String> = ["authorization", "cookie", "set-cookie", "proxy-authorization"]
        var redacted: [String: String] = [:]
        for (key, value) in headers {
            if sensitive.contains(key.lowercased()) {
                redacted[key] = "•••redacted•••"
            } else {
                redacted[key] = value
            }
        }
        return redacted
    }

    func shouldIgnore(host: String?) -> Bool {
        guard let host else { return false }
        return ignoredHosts.contains { host.hasSuffix($0) }
    }
}
