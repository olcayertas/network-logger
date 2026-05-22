#if os(iOS)
import SwiftUI

struct StatsView: View {
    let events: [NetworkEvent]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("General") {
                    if events.isEmpty {
                        Text("No data").foregroundStyle(.secondary)
                    } else {
                        row("Total requests", "\(events.count)")
                        row("Success rate", percentage(successCount))
                        row("Client errors", percentage(clientErrorCount))
                        row("Server errors", percentage(serverErrorCount))
                        if let avg = averageDuration {
                            row("Avg duration", String(format: "%.0f ms", avg * 1000))
                        }
                    }
                }

                Section("HTTP Methods") {
                    ForEach(methodCounts.sorted { $0.key < $1.key }, id: \.key) { method, count in
                        row(method, "\(count) — \(String(format: "%.1f", Double(count) / Double(events.count) * 100))%")
                    }
                }

                Section("Status codes") {
                    ForEach(statusCounts.sorted { $0.key < $1.key }, id: \.key) { code, count in
                        row("\(code)", "\(count)")
                    }
                }

                Section("Data transferred") {
                    row("Sent", byteString(bytesSent))
                    row("Received", byteString(bytesReceived))
                }
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }

    private var successCount: Int {
        events.filter { (200..<300).contains($0.response?.statusCode ?? 0) }.count
    }
    private var clientErrorCount: Int {
        events.filter { (400..<500).contains($0.response?.statusCode ?? 0) }.count
    }
    private var serverErrorCount: Int {
        events.filter { (500..<600).contains($0.response?.statusCode ?? 0) }.count
    }

    private var averageDuration: TimeInterval? {
        let durations = events.compactMap { $0.metrics.duration }
        guard !durations.isEmpty else { return nil }
        return durations.reduce(0, +) / Double(durations.count)
    }

    private var methodCounts: [String: Int] {
        events.reduce(into: [:]) { result, event in
            result[event.request.httpMethod.uppercased(), default: 0] += 1
        }
    }

    private var statusCounts: [Int: Int] {
        events.reduce(into: [:]) { result, event in
            if let code = event.response?.statusCode, code > 0 {
                result[code, default: 0] += 1
            }
        }
    }

    private var bytesSent: Int64 {
        events.reduce(0) { $0 + ($1.metrics.requestBodyBytesSent ?? 0) }
    }

    private var bytesReceived: Int64 {
        events.reduce(0) { $0 + ($1.metrics.responseBodyBytesReceived ?? 0) }
    }

    private func percentage(_ count: Int) -> String {
        guard !events.isEmpty else { return "—" }
        let pct = Double(count) / Double(events.count) * 100
        return String(format: "%.1f%% (%d)", pct, count)
    }

    private func byteString(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}
#endif
