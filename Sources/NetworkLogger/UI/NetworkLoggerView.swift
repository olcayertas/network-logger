#if os(iOS)
import SwiftUI
import Perception

public struct NetworkLoggerView: View {
    let logger: NetworkLogger
    let bodyViewers: [any BodyViewer]
    @State private var listModel: EventListModel?
    @State private var consoleModel: LogEventListModel?
    @State private var settings = AppearanceSettings.shared
    @State private var showAppearanceSheet = false
    @State private var selectedTab: Tab = .network

    public init(logger: NetworkLogger, bodyViewers: [any BodyViewer] = []) {
        self.logger = logger
        self.bodyViewers = bodyViewers
    }

    public var body: some View {
        WithPerceptionTracking {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    networkContent
                        .toolbar { appearanceToolbarItem }
                        .sheet(isPresented: $showAppearanceSheet) {
                            AppearanceSettingsView(settings: settings)
                        }
                }
                .tabItem { Label("Network", systemImage: "network") }
                .tag(Tab.network)

                NavigationStack {
                    consoleContent
                        .toolbar { appearanceToolbarItem }
                        .sheet(isPresented: $showAppearanceSheet) {
                            AppearanceSettingsView(settings: settings)
                        }
                }
                .tabItem { Label("Console", systemImage: "text.alignleft") }
                .tag(Tab.console)
            }
            .tint(settings.accent.color)
            .preferredColorScheme(settings.colorScheme.swiftUI)
            .environment(\.networkLoggerAppearance, settings)
            .environment(\.bodyViewers, bodyViewers)
        }
    }

    @ToolbarContentBuilder
    private var appearanceToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showAppearanceSheet = true
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .accessibilityLabel("Appearance")
        }
    }

    @ViewBuilder
    private var networkContent: some View {
        if logger.persistence != nil {
            SessionListView(logger: logger)
        } else if let listModel {
            RequestListView(model: listModel, logger: logger)
        } else {
            ProgressView()
                .task {
                    let model = EventListModel(logger: logger)
                    model.start()
                    listModel = model
                }
        }
    }

    @ViewBuilder
    private var consoleContent: some View {
        if let consoleModel {
            ConsoleView(model: consoleModel, logger: logger)
        } else {
            ProgressView()
                .task {
                    consoleModel = LogEventListModel(logger: logger)
                }
        }
    }

    private enum Tab: Hashable { case network, console }
}
#endif
