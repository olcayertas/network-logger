#if os(iOS)
import SwiftUI
import Perception

public struct NetworkLoggerView: View {
    let logger: NetworkLogger
    @State private var listModel: EventListModel?
    @State private var settings = AppearanceSettings.shared
    @State private var showAppearanceSheet = false

    public init(logger: NetworkLogger) {
        self.logger = logger
    }

    public var body: some View {
        WithPerceptionTracking {
            NavigationStack {
                Group {
                    if let listModel {
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
        }
    }
}
#endif
