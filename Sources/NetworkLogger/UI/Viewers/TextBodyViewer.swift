#if os(iOS)
import SwiftUI

/// Renders body data as UTF-8 text, falling back to `<binary N bytes>` if decoding fails.
///
/// Acts as the default tail of `BodyViewerResolver` — its `canHandle(...)` always
/// returns `true`, so it's reached when nothing else matches.
public struct TextBodyViewer: BodyViewer {
    public static let shared = TextBodyViewer()

    public init() {}

    public func canHandle(mimeType: String?, body: BodyData) -> Bool { true }

    public func makeView(body: BodyData, mimeType: String?, context: BodyViewerContext) -> AnyView {
        let formatted: String
        if let text = body.text(), !text.isEmpty {
            formatted = text
        } else {
            formatted = "<binary \(body.byteCount) bytes>"
        }
        var attributed = AttributedString(formatted)
        BodyViewerSearchHighlight.apply(searchText: context.searchText, in: &attributed, source: formatted)
        return AnyView(
            ScrollableBody(attributed: attributed, raw: formatted, fontSize: context.bodyFontSize)
        )
    }
}

/// Shared scrolling-monospaced-text shell used by JSON and Text viewers.
struct ScrollableBody: View {
    let attributed: AttributedString
    let raw: String
    let fontSize: Double
    @State private var showCopiedAlert = false

    var body: some View {
        ScrollView {
            Text(attributed)
                .font(.system(size: fontSize, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .textSelection(.enabled)
                .onTapGesture {
                    UIPasteboard.general.string = raw
                    showCopiedAlert = true
                }
        }
        .alert("Copied", isPresented: $showCopiedAlert) {
            Button("OK", role: .cancel) {}
        }
    }
}
#endif
