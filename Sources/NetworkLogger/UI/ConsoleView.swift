#if os(iOS)
import SwiftUI
import Perception

/// In-app console for `LogEvent`s, sibling to `RequestListView`. Wired up automatically
/// when `NetworkLoggerLogHandler` is bootstrapped as the swift-log backend; consumers
/// can also feed log events directly via `await logger.log(_:)`.
struct ConsoleView: View {
    @Perception.Bindable var model: LogEventListModel
    let logger: NetworkLogger

    @State private var showClearConfirmation = false
    @State private var showLevelPicker = false

    init(model: LogEventListModel, logger: NetworkLogger) {
        self._model = Perception.Bindable(model)
        self.logger = logger
    }

    var body: some View {
        WithPerceptionTracking {
            List {
                if let level = model.minLevel {
                    Section {
                        HStack {
                            Label("Level ≥ \(level.rawValue)", systemImage: "flag.fill")
                                .foregroundStyle(Color.accentColor)
                            Spacer()
                            Button("Clear") { model.minLevel = nil }
                                .font(.caption)
                        }
                    }
                }
                if let label = model.focusedLabel {
                    Section {
                        HStack {
                            Label(label, systemImage: "tag.fill")
                                .foregroundStyle(Color.accentColor)
                            Spacer()
                            Button("Clear") { model.focusedLabel = nil }
                                .font(.caption)
                        }
                    }
                }
                Section {
                    ForEach(model.filtered) { event in
                        NavigationLink(value: event) {
                            LogEventRow(event: event)
                        }
                    }
                }
                if model.filtered.isEmpty {
                    Section {
                        Text(model.events.isEmpty ? "No log entries yet." : "No matching entries.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Console")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $model.searchText, prompt: Text("Filter logs"))
            .navigationDestination(for: LogEvent.self) { event in
                LogEventDetailView(event: event)
            }
            .task { model.start() }
            .onDisappear { model.stop() }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Menu("Minimum level") {
                            ForEach(LogEvent.Level.allCases, id: \.self) { level in
                                Button {
                                    model.minLevel = level
                                } label: {
                                    Label(level.rawValue, systemImage: levelIcon(level))
                                }
                            }
                            Button("Any level") { model.minLevel = nil }
                        }
                        if !model.availableLabels.isEmpty {
                            Menu("Filter by label") {
                                ForEach(model.availableLabels, id: \.self) { label in
                                    Button(label) { model.focusedLabel = label }
                                }
                                Button("All labels") { model.focusedLabel = nil }
                            }
                        }
                        if !model.isReadOnly {
                            Divider()
                            Button(role: .destructive) {
                                showClearConfirmation = true
                            } label: {
                                Label("Clear", systemImage: "trash")
                            }
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
            .confirmationDialog(
                "Clear log entries?",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) { model.clear() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func levelIcon(_ level: LogEvent.Level) -> String {
        switch level {
        case .trace: return "circle"
        case .debug: return "ladybug"
        case .info: return "info.circle"
        case .notice: return "bell"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.octagon"
        case .critical: return "flame"
        }
    }
}
#endif
