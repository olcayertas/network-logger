import Logging
import NetworkLogger

public extension NetworkLoggerLogHandler {
    /// One-line bootstrap that routes every `Logger(label:)` instance through
    /// `NetworkLoggerLogHandler`. Call once at app startup, before creating any
    /// `Logger`s you want captured.
    ///
    /// Per swift-log's contract, `LoggingSystem.bootstrap(_:)` can be called at most once
    /// per process; calling it twice will trap. For test code use
    /// `bootstrapInternal(_:)` instead (see swift-log docs).
    static func bootstrap(logger: NetworkLogger, minimumLevel: Logger.Level = .info) {
        LoggingSystem.bootstrap { label in
            var handler = NetworkLoggerLogHandler(label: label, logger: logger)
            handler.logLevel = minimumLevel
            return handler
        }
    }
}
