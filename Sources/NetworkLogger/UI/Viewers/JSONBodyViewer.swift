#if os(iOS)
import SwiftUI

/// Pretty-prints JSON bodies and overlays syntax + search highlighting on top.
///
/// `canHandle` succeeds only when `JSONFormatter.prettyPrint(_:)` returns non-nil, so a
/// body labelled `application/json` that's actually garbage falls through to
/// `TextBodyViewer`.
public struct JSONBodyViewer: BodyViewer {
    public static let shared = JSONBodyViewer()

    public init() {}

    public func canHandle(mimeType: String?, body: BodyData) -> Bool {
        JSONFormatter.prettyPrint(body.data) != nil
    }

    public func makeView(body: BodyData, mimeType: String?, context: BodyViewerContext) -> AnyView {
        guard let formatted = JSONFormatter.prettyPrint(body.data) else {
            return AnyView(EmptyView())
        }
        var attributed = JSONHighlighter.attributed(formatted, theme: context.syntaxTheme)
        BodyViewerSearchHighlight.apply(searchText: context.searchText, in: &attributed, source: formatted)
        return AnyView(
            ScrollableBody(attributed: attributed, raw: formatted, fontSize: context.bodyFontSize)
        )
    }
}
#endif
