#if canImport(SwiftUI)
import Foundation
import Perception

@MainActor
@Perceptible
public final class EventDetailModel {
    public private(set) var event: NetworkEvent

    @PerceptionIgnored
    private let logger: NetworkLogger

    @PerceptionIgnored
    private var streamTask: Task<Void, Never>?

    public init(event: NetworkEvent, logger: NetworkLogger) {
        self.event = event
        self.logger = logger
    }

    public func start() {
        streamTask?.cancel()
        let id = event.id
        streamTask = Task { [weak self] in
            guard let stream = await self?.logger.eventStream() else { return }
            for await snapshot in stream {
                guard let self else { break }
                if let updated = snapshot.first(where: { $0.id == id }) {
                    self.event = updated
                }
            }
        }
    }

    public func stop() {
        streamTask?.cancel()
        streamTask = nil
    }
}
#endif
