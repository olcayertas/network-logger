import Dependencies
import NetworkLogger

extension NetworkLogger: DependencyKey {
    public static let liveValue = NetworkLogger()
    public static var testValue: NetworkLogger { NetworkLogger() }
    public static var previewValue: NetworkLogger { NetworkLogger() }
}

public extension DependencyValues {
    /// The shared `NetworkLogger` instance for this app.
    ///
    /// Configure once at app startup with `prepareDependencies`:
    ///
    /// ```swift
    /// @main
    /// struct MyApp: App {
    ///     init() {
    ///         prepareDependencies {
    ///             $0.networkLogger = NetworkLogger(configuration: .init(
    ///                 limit: 500,
    ///                 ignoredHosts: ["analytics.example.com"]
    ///             ))
    ///         }
    ///     }
    ///     var body: some Scene { WindowGroup { ContentView() } }
    /// }
    /// ```
    ///
    /// Then read it anywhere:
    ///
    /// ```swift
    /// @Dependency(\.networkLogger) var logger
    /// ```
    var networkLogger: NetworkLogger {
        get { self[NetworkLogger.self] }
        set { self[NetworkLogger.self] = newValue }
    }
}
