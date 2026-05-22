#if os(iOS)
import SwiftUI

struct StatusCodeFilterChip: View {
    @Binding var selected: StatusCodeRangeFilter?

    private let options: [(label: String, filter: StatusCodeRangeFilter?)] = [
        ("All", nil),
        ("1xx", .informational),
        ("2xx", .success),
        ("3xx", .redirection),
        ("4xx", .clientError),
        ("5xx", .serverError),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(0..<options.count, id: \.self) { index in
                    let option = options[index]
                    Button {
                        selected = option.filter
                    } label: {
                        Text(option.label)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                isSelected(option.filter) ? Color.accentColor : Color(.secondarySystemBackground),
                                in: Capsule()
                            )
                            .foregroundStyle(isSelected(option.filter) ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func isSelected(_ option: StatusCodeRangeFilter?) -> Bool {
        selected?.range == option?.range
    }
}
#endif
