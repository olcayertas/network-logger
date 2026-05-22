#if os(iOS)
import SwiftUI
import Perception

public struct NetworkLoggerView: View {
    let logger: NetworkLogger
    let bodyViewers: [any BodyViewer]
    @State private var listModel: EventListModel?
    @State private var settings = AppearanceSettings.shared
    @State private var showAppearanceSheet = false

    public init(logger: NetworkLogger, bodyViewers: [any BodyViewer] = []) {
        self.logger = logger
        self.bodyViewers = bodyViewers
    }

    public var body: some View {
        WithPerceptionTracking {
            NavigationStack {
                content
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                showAppearanceSheet = true
                            } label: {
                                Image(systemName: "slider.horizontal.3")
                            }
                            .accessibilityLabel("Appearance")
                        }
                    }
                    .sheet(isPresented: $showAppearanceSheet) {
                        AppearanceSettingsView(settings: settings)
                    }
            }
            .tint(settings.accent.color)
            .preferredColorScheme(settings.colorScheme.swiftUI)
            .environment(\.networkLoggerAppearance, settings)
            .environment(\.bodyViewers, bodyViewers)
        }
    }

    @ViewBuilder
    private var content: some View {
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
}
#endif
