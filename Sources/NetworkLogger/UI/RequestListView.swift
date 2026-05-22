#if os(iOS)
import SwiftUI
import Perception
import UIKit

struct RequestListView: View {
    @Perception.Bindable var model: EventListModel
    let logger: NetworkLogger?

    @State private var showStats = false
    @State private var showClearConfirmation = false
    @State private var sharePayload: SharePayload?
    @Environment(\.dismiss) private var dismiss

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

                Section {
                    ForEach(model.filtered) { event in
                        NavigationLink(value: event) {
                            RequestRow(event: event)
                                .padding(.vertical, 6)
                        }
                    }
                }

                if model.filtered.isEmpty {
                    Section {
                        Text(model.events.isEmpty ? "No requests captured yet." : "No matching requests.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Requests")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $model.searchText, prompt: Text("Filter by URL"))
            .navigationDestination(for: NetworkEvent.self) { event in
                RequestDetailView(model: EventDetailModel(event: event, logger: logger))
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
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
                            sharePayload = .init(events: model.filtered, format: .plainText)
                        } label: {
                            Label("Share as text", systemImage: "square.and.arrow.up")
                        }
                        .disabled(model.filtered.isEmpty)
                        Button {
                            sharePayload = .init(events: model.filtered, format: .curl)
                        } label: {
                            Label("Share as cURL", systemImage: "terminal")
                        }
                        .disabled(model.filtered.isEmpty)
                        Button {
                            sharePayload = .init(events: model.filtered, format: .postman)
                        } label: {
                            Label("Share as Postman", systemImage: "shippingbox")
                        }
                        .disabled(model.filtered.isEmpty)
                        Button {
                            sharePayload = .init(events: model.filtered, format: .har)
                        } label: {
                            Label("Share as HAR", systemImage: "doc.text")
                        }
                        .disabled(model.filtered.isEmpty)
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
