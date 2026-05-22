import Foundation

actor ConfigurationStore {
    private(set) var current: NetworkLoggerConfiguration

    init(_ configuration: NetworkLoggerConfiguration) {
        self.current = configuration
    }

    func replace(with new: NetworkLoggerConfiguration) {
        current = new
    }

    func mutate(_ transform: @Sendable (inout NetworkLoggerConfiguration) -> Void) {
        transform(&current)
    }
}
