import Foundation

/// A single app-log entry sitting alongside `NetworkEvent`s in the logger.
///
/// Level / label / metadata mirror the swift-log shape so the optional
/// `NetworkLoggerLogHandler` product can produce these without lossy conversion.
public struct LogEvent: Sendable, Identifiable, Equatable, Hashable, Codable {
    public let id: UUID
    public let date: Date
    public let level: Level
    public let label: String
    public let message: String
    public let source: String?
    public let file: String?
    public let function: String?
    public let line: UInt?
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        level: Level,
        label: String,
        message: String,
        source: String? = nil,
        file: String? = nil,
        function: String? = nil,
        line: UInt? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.date = date
        self.level = level
        self.label = label
        self.message = message
        self.source = source
        self.file = file
        self.function = function
        self.line = line
        self.metadata = metadata
    }

    public enum Level: String, Sendable, Codable, Hashable, CaseIterable, Comparable {
        case trace, debug, info, notice, warning, error, critical

        public static func < (lhs: Level, rhs: Level) -> Bool {
            lhs.severity < rhs.severity
        }

        public var severity: Int {
            switch self {
            case .trace: return 0
            case .debug: return 1
            case .info: return 2
            case .notice: return 3
            case .warning: return 4
            case .error: return 5
            case .critical: return 6
            }
        }
    }
}
