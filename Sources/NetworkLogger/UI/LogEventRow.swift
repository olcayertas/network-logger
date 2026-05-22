#if os(iOS)
import SwiftUI

struct LogEventRow: View {
    let event: LogEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            levelBadge
            VStack(alignment: .leading, spacing: 4) {
                Text(event.message)
                    .font(.subheadline)
                    .lineLimit(3)
                HStack(spacing: 8) {
                    Text(event.label)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(.secondary)
                    Text(event.date, format: .dateTime.hour().minute().second())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var levelBadge: some View {
        Text(event.level.rawValue.uppercased().prefix(4))
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(levelColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(levelColor)
    }

    private var levelColor: Color {
        switch event.level {
        case .trace: return .secondary
        case .debug: return .blue
        case .info: return .green
        case .notice: return .teal
        case .warning: return .orange
        case .error: return .red
        case .critical: return .pink
        }
    }
}
#endif
