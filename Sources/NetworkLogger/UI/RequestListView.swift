#if os(iOS)
import SwiftUI
import Perception
import Sharing
import UIKit

struct RequestListView: View {
    @Perception.Bindable var model: EventListModel
    let logger: NetworkLogger
    @SharedReader var pinnedIDs: Set<UUID>
    @SharedReader var recentSearches: RecentSearches

    init(model: EventListModel, logger: NetworkLogger) {
        self._model = Perception.Bindable(model)
        self.logger = logger
        self._pinnedIDs = SharedReader(logger.pinnedEvents.shared)
        self._recentSearches = SharedReader(logger.recentSearches.shared)
    }

    @State private var showStats = false
    @State private var showClearConfirmation = false
    @State private var sharePayload: SharePayload?
    @State private var showPinnedOnly = false
    @State private var showDateRangePicker = false
    @Environment(\.dismiss) private var dismiss

    private var visibleEvents: [NetworkEvent] {
        showPinnedOnly ? model.filtered.filter { pinnedIDs.contains($0.id) } : model.filtered
    }

    private var emptyMessage: String {
        if showPinnedOnly { return "No pinned requests yet." }
        return model.events.isEmpty ? "No requests captured yet." : "No matching requests."
    }

    var body: some View {
        WithPerceptionTracking {
            List {
                if !model.events.isEmpty {
                    Section {
                        StatusCodeFilterChip(selected: $model.statusCodeFilter)
                            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 4, trailing: 8))
                            .listRowBackground(Color.clear)
                    }
                }

                if !model.parsedSearch.tokens.isEmpty || model.dateRange != nil {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(model.parsedSearch.tokens, id: \.self) { token in
                                    FilterChip(systemImage: token.systemImage, label: token.displayLabel) {
                                        model.remove(token)
                                    }
                                }
                                if let range = model.dateRange {
                                    FilterChip(systemImage: "clock", label: Self.formatRange(range)) {
                                        model.dateRange = nil
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                        .listRowBackground(Color.clear)
                    }
                }

                Section {
                    ForEach(visibleEvents) { event in
                        NavigationLink(value: event) {
                            RequestRow(event: event, isPinned: pinnedIDs.contains(event.id))
                                .padding(.vertical, 6)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                logger.pinnedEvents.togglePin(event.id)
                            } label: {
                                if pinnedIDs.contains(event.id) {
                                    Label("Unpin", systemImage: "pin.slash.fill")
                                } else {
                                    Label("Pin", systemImage: "pin.fill")
                                }
                            }
                            .tint(.accentColor)
                        }
                    }
                }

                if visibleEvents.isEmpty {
                    Section {
                        Text(emptyMessage)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Requests")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $model.searchText, prompt: Text("Filter by URL"))
            .searchSuggestions {
                if model.searchText.isEmpty {
                    ForEach(recentSearches.searches, id: \.self) { term in
                        Label(term, systemImage: "clock.arrow.circlepath")
                            .searchCompletion(term)
                    }
                }
            }
            .onSubmit(of: .search) {
                logger.recentSearches.record(model.searchText)
            }
            .navigationDestination(for: NetworkEvent.self) { event in
                RequestDetailView(model: EventDetailModel(event: event, logger: model.logger), logger: logger)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showDateRangePicker = true
                    } label: {
                        Image(systemName: model.dateRange == nil ? "clock" : "clock.fill")
                            .foregroundStyle(model.dateRange == nil ? .secondary : Color.accentColor)
                    }
                    .accessibilityLabel("Date range filter")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation { showPinnedOnly.toggle() }
                    } label: {
                        Image(systemName: showPinnedOnly ? "pin.fill" : "pin")
                            .foregroundStyle(showPinnedOnly ? Color.accentColor : .secondary)
                    }
                    .accessibilityLabel(showPinnedOnly ? "Show all" : "Show pinned only")
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showStats = true
                        } label: {
                            Label("Stats", systemImage: "chart.bar")
                        }
                        Divider()
                        Button {
                            sharePayload = .init(events: visibleEvents, format: .plainText)
                        } label: {
                            Label("Share as text", systemImage: "square.and.arrow.up")
                        }
                        .disabled(visibleEvents.isEmpty)
                        Button {
                            sharePayload = .init(events: visibleEvents, format: .curl)
                        } label: {
                            Label("Share as cURL", systemImage: "terminal")
                        }
                        .disabled(visibleEvents.isEmpty)
                        Button {
                            sharePayload = .init(events: visibleEvents, format: .postman)
                        } label: {
                            Label("Share as Postman", systemImage: "shippingbox")
                        }
                        .disabled(visibleEvents.isEmpty)
                        Button {
                            sharePayload = .init(events: visibleEvents, format: .har)
                        } label: {
                            Label("Share as HAR", systemImage: "doc.text")
                        }
                        .disabled(visibleEvents.isEmpty)
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
            .sheet(isPresented: $showStats) {
                StatsView(events: model.events)
            }
            .sheet(isPresented: $showDateRangePicker) {
                DateRangePickerView(range: $model.dateRange)
            }
            .sheet(item: $sharePayload) { payload in
                ShareSheet(items: payload.items)
            }
            .confirmationDialog(
                "Clear captured requests?",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) { model.clear() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

extension RequestListView {
    fileprivate static func formatRange(_ range: ClosedRange<Date>) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        if Calendar.current.isDate(range.lowerBound, inSameDayAs: range.upperBound),
           Calendar.current.isDateInToday(range.lowerBound) {
            return "\(formatter.string(from: range.lowerBound))–\(formatter.string(from: range.upperBound))"
        }
        formatter.dateStyle = .short
        return "\(formatter.string(from: range.lowerBound)) – \(formatter.string(from: range.upperBound))"
    }
}

private struct FilterChip: View {
    let systemImage: String
    let label: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption2)
            Text(label)
                .font(.caption.weight(.medium))
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.12), in: Capsule())
    }
}

private struct SharePayload: Identifiable {
    let id = UUID()
    let events: [NetworkEvent]
    let format: ExportFormat

    var items: [Any] {
        switch format {
        case .plainText: return [PlainTextExporter.text(for: events)]
        case .curl: return [CurlExporter.string(for: events)]
        case .postman: return [String(data: PostmanExporter.collection(name: "NetworkLogger", from: events), encoding: .utf8) ?? "{}"]
        case .har: return [String(data: HARExporter.har(from: events), encoding: .utf8) ?? "{}"]
        }
    }

    enum ExportFormat {
        case plainText
        case curl
        case postman
        case har
    }
}
#endif
