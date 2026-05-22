#if os(iOS)
import Dependencies
import NetworkLogger
import SwiftUI

/// A SwiftUI view that presents the configured `NetworkLogger` from the
/// `@Dependency(\.networkLogger)` scope. Drop-in replacement for
/// `NetworkLoggerView(logger:)` when you don't want to thread the logger
/// through your view hierarchy.
///
/// ```swift
/// Button("Network logs") { showLogs = true }
///     .sheet(isPresented: $showLogs) {
///         NetworkLoggerInspector()
///     }
/// ```
public struct NetworkLoggerInspector: View {
    @Dependency(\.networkLogger) private var logger

    public init() {}

    public var body: some View {
        NetworkLoggerView(logger: logger)
    }
}
#endif
