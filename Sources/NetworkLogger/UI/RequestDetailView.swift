#if os(iOS)
import SwiftUI
import UIKit
import Perception
import Sharing

struct RequestDetailView: View {
    @Perception.Bindable var model: EventDetailModel
    let logger: NetworkLogger
    @SharedReader var pinnedIDs: Set<UUID>
    @State private var sharePayload: SharePayload?
    @State private var showCopiedAlert = false

    init(model: EventDetailModel, logger: NetworkLogger) {
        self._model = Perception.Bindable(model)
        self.logger = logger
        self._pinnedIDs = SharedReader(logger.pinnedEvents.shared)
    }

    var body: some View {
        WithPerceptionTracking {
            let event = model.event
            List {
                Section("Overview") {
                    OverviewSection(event: event)
                        .onTapGesture {
                            copy(PlainTextExporter.text(for: event))
                        }
                }

                Section("Request Headers") {
                    HeadersSection(headers: event.request.headers)
                }

                Section("Request Body") {
                    if let body = event.request.body, !body.data.isEmpty {
                        NavigationLink("View body (\(body.byteCount) bytes)") {
                            BodyDetailView(payload: body, title: "Request Body", mimeType: event.request.headers["Content-Type"] ?? event.request.headers["content-type"])
                        }
                    } else {
                        Text("No body").foregroundStyle(.secondary)
                    }
                }

                Section("Response Headers") {
                    HeadersSection(headers: event.response?.headers ?? [:])
                }

                Section("Response Body") {
                    if let body = event.response?.body, !body.data.isEmpty {
                        NavigationLink("View body (\(body.byteCount) bytes)") {
                            BodyDetailView(payload: body, title: "Response Body", mimeType: event.response?.mimeType)
                        }
                    } else {
                        Text("No body").foregroundStyle(.secondary)
                    }
                }

                if let error = event.error {
                    Section("Error") {
                        Text("\(error.message)\nCode: \(error.code)\nDomain: \(error.domain)")
                            .foregroundStyle(.red)
                            .onTapGesture {
                                copy(error.message)
                            }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .textSelection(.enabled)
            .navigationTitle(URL(string: event.request.url.absoluteString)?.lastPathComponent ?? "Request")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                model.start()
            }
            .onDisappear {
                model.stop()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        logger.pinnedEvents.togglePin(event.id)
                    } label: {
                        Image(systemName: pinnedIDs.contains(event.id) ? "pin.fill" : "pin")
                            .foregroundStyle(pinnedIDs.contains(event.id) ? Color.accentColor : .secondary)
                    }
                    .accessibilityLabel(pinnedIDs.contains(event.id) ? "Unpin" : "Pin")
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            sharePayload = .init(events: [event], format: .plainText)
                        } label: {
                            Label("Share as text", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            sharePayload = .init(events: [event], format: .curl)
                        } label: {
                            Label("Share as cURL", systemImage: "terminal")
                        }
                        Button {
                            sharePayload = .init(events: [event], format: .postman)
                        } label: {
                            Label("Share as Postman", systemImage: "shippingbox")
                        }
                    } label: {
                        Label("Share", systemImage: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $sharePayload) { payload in
                ShareSheet(items: payload.items)
            }
            .alert("Copied", isPresented: $showCopiedAlert) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func copy(_ text: String) {
        UIPasteboard.general.string = text
        showCopiedAlert = true
    }
}

private struct OverviewSection: View {
    let event: NetworkEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            row("URL", event.request.url.absoluteString)
            row("Method", event.request.httpMethod)
            row("Status", event.response.map { "\($0.statusCode)" } ?? "-")
            if let duration = event.metrics.duration {
                row("Duration", String(format: "%.0f ms", duration * 1000))
            }
            if let sent = event.metrics.requestBodyBytesSent {
                row("Request bytes sent", "\(sent)")
            }
            if let received = event.metrics.responseBodyBytesReceived {
                row("Response bytes received", "\(received)")
            }
        }
        .font(.callout)
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value).multilineTextAlignment(.trailing)
        }
    }
}

private struct HeadersSection: View {
    let headers: [String: String]

    var body: some View {
        if headers.isEmpty {
            Text("None").foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(headers.keys.sorted(), id: \.self) { key in
                    HStack(alignment: .top) {
                        Text(key)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 130, alignment: .leading)
                        if let value = headers[key], let jwt = jwtIfAuthorization(key: key, value: value) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(value)
                                    .font(.caption)
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                                    .textSelection(.enabled)
                                JWTBadgeView(jwt: jwt)
                            }
                        } else {
                            Text(headers[key] ?? "")
                                .font(.caption)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        }
    }

    private func jwtIfAuthorization(key: String, value: String) -> JWT? {
        guard key.lowercased() == "authorization" else { return nil }
        return JWTDetector.jwtFromAuthorizationHeader(value)
    }
}

private struct SharePayload: Identifiable {
    let id = UUID()
    let events: [NetworkEvent]
    let format: Format

    var items: [Any] {
        switch format {
        case .plainText: return [PlainTextExporter.text(for: events)]
        case .curl: return [CurlExporter.string(for: events)]
        case .postman: return [String(data: PostmanExporter.collection(name: "NetworkLogger", from: events), encoding: .utf8) ?? "{}"]
        }
    }

    enum Format {
        case plainText, curl, postman
    }
}
#endif
