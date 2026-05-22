#if os(iOS)
import SwiftUI
import UIKit

struct LogEventDetailView: View {
    let event: LogEvent
    @State private var showCopiedAlert = false

    var body: some View {
        List {
            Section("Message") {
                Text(event.message)
                    .textSelection(.enabled)
                    .onTapGesture {
                        UIPasteboard.general.string = event.message
                        showCopiedAlert = true
                    }
            }
            Section("Origin") {
                row("Level", value: event.level.rawValue)
                row("Label", value: event.label)
                row("Date", value: event.date.formatted(date: .abbreviated, time: .standard))
                if let source = event.source { row("Source", value: source) }
                if let file = event.file { row("File", value: shortFile(file)) }
                if let function = event.function { row("Function", value: function) }
                if let line = event.line { row("Line", value: String(line)) }
            }
            if !event.metadata.isEmpty {
                Section("Metadata") {
                    ForEach(event.metadata.keys.sorted(), id: \.self) { key in
                        row(key, value: event.metadata[key] ?? "")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Log entry")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Copied", isPresented: $showCopiedAlert) {
            Button("OK", role: .cancel) {}
        }
    }

    private func row(_ label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
        }
    }

    private func shortFile(_ file: String) -> String {
        URL(fileURLWithPath: file).lastPathComponent
    }
}
#endif
