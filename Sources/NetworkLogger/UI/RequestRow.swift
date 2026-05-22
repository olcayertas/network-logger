#if os(iOS)
import SwiftUI

struct RequestRow: View {
    let event: NetworkEvent
    var isPinned: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            statusBadge
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.accentColor)
                    }
                    Text(event.request.url.absoluteString)
                        .font(.system(.subheadline, design: .monospaced))
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                HStack(spacing: 8) {
                    Text(event.request.httpMethod)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(methodColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(methodColor)
                    if let duration = event.metrics.duration {
                        Text("\(Int(duration * 1000)) ms")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if event.state == .inFlight {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                }
            }
        }
    }

    private var statusBadge: some View {
        Group {
            if let code = event.response?.statusCode, code > 0 {
                Text("\(code)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(statusColor)
            } else if event.state == .failed {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            } else if event.state == .cancelled {
                Image(systemName: "minus.circle")
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "circle.dashed")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusColor: Color {
        guard let code = event.response?.statusCode else { return .secondary }
        switch code {
        case 100..<200: return .indigo
        case 200..<300: return .green
        case 300..<400: return .blue
        case 400..<500: return .orange
        case 500..<600: return .red
        default: return .secondary
        }
    }

    private var methodColor: Color {
        switch event.request.httpMethod.uppercased() {
        case "GET": return .blue
        case "POST": return .green
        case "PUT": return .indigo
        case "PATCH": return .purple
        case "DELETE": return .red
        default: return .secondary
        }
    }
}
#endif
