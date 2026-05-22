import Foundation
import struct Logging.Logger
import protocol Logging.LogHandler
import NetworkLogger

/// `LogHandler` conformance that bridges swift-log into a `NetworkLogger.LogEventStore`.
///
/// Each log call constructs a `LogEvent` and forwards it to `NetworkLogger.log(_:)`.
/// Both per-call metadata and handler-attached metadata are merged, with per-call
/// metadata winning on conflict (matching swift-log's documented behaviour).
///
/// ```swift
/// LoggingSystem.bootstrap { label in
///     NetworkLoggerLogHandler(label: label, logger: sharedLogger)
/// }
/// ```
public struct NetworkLoggerLogHandler: LogHandler, Sendable {
    public let label: String
    public let logger: NetworkLogger

    public var logLevel: Logger.Level = .info
    public var metadata: Logger.Metadata = [:]

    public init(label: String, logger: NetworkLogger) {
        self.label = label
        self.logger = logger
    }

    public subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata explicitMetadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        let merged = Self.merge(handler: metadata, call: explicitMetadata)
        let stringified = merged.mapValues { "\($0)" }
        let event = LogEvent(
            level: Self.bridge(level),
            label: label,
            message: message.description,
            source: source,
            file: file,
            function: function,
            line: line,
            metadata: stringified
        )
        let logger = logger
        Task { await logger.log(event) }
    }

    static func bridge(_ level: Logger.Level) -> LogEvent.Level {
        switch level {
        case .trace: return .trace
        case .debug: return .debug
        case .info: return .info
        case .notice: return .notice
        case .warning: return .warning
        case .error: return .error
        case .critical: return .critical
        }
    }

    static func merge(handler: Logger.Metadata, call: Logger.Metadata?) -> Logger.Metadata {
        guard let call, !call.isEmpty else { return handler }
        var merged = handler
        for (key, value) in call {
            merged[key] = value
        }
        return merged
    }
}
