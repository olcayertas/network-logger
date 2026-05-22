#if canImport(SwiftUI)
import Foundation
import Perception

@MainActor
@Perceptible
public final class LogEventListModel {
    public private(set) var events: [LogEvent] = []
    public var searchText: String = ""
    public var minLevel: LogEvent.Level? = nil
    public var focusedLabel: String? = nil

    @PerceptionIgnored
    private let logger: NetworkLogger?

    @PerceptionIgnored
    private var streamTask: Task<Void, Never>?

    public init(logger: NetworkLogger) {
        self.logger = logger
    }

    public init(snapshot: [LogEvent]) {
        self.logger = nil
        self.events = snapshot
    }

    public var isReadOnly: Bool { logger == nil }

    public func start() {
        guard let logger else { return }
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            let stream = await logger.logStore.stream()
            for await snapshot in stream {
                guard let self else { break }
                self.events = snapshot
            }
        }
    }

    public func stop() {
        streamTask?.cancel()
        streamTask = nil
    }

    public func clear() {
        guard let logger else { return }
        Task { await logger.logStore.clear() }
    }

    public var availableLabels: [String] {
        Array(Set(events.map(\.label))).sorted()
    }

    public var filtered: [LogEvent] {
        events
            .filter { event in
                if let minLevel, event.level < minLevel { return false }
                if let focusedLabel, event.label != focusedLabel { return false }
                if !searchText.isEmpty {
                    let needle = searchText
                    let inMessage = event.message.range(of: needle, options: .caseInsensitive) != nil
                    let inLabel = event.label.range(of: needle, options: .caseInsensitive) != nil
                    if !inMessage, !inLabel { return false }
                }
                return true
            }
            .sorted { $0.date > $1.date }
    }
}
#endif
