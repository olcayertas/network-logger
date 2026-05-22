#if os(iOS)
import SwiftUI
import WebKit
import NetworkLogger

/// Renders an HTML body inside a sandboxed `WKWebView` with JavaScript disabled.
///
/// `canHandle` accepts `text/html` and `application/xhtml+xml`. Search highlighting is
/// not applied — users can still use the page's `Find on Page` via long-press if they
/// need it.
public struct HTMLBodyViewer: BodyViewer {
    public init() {}

    public func canHandle(mimeType: String?, body: BodyData) -> Bool {
        guard let mimeType = mimeType?.lowercased() else { return false }
        return mimeType.contains("html") || mimeType == "application/xhtml+xml"
    }

    public func makeView(body: BodyData, mimeType: String?, context: BodyViewerContext) -> AnyView {
        let encoding = String.Encoding.utf8
        let html = String(data: body.data, encoding: encoding) ?? "<pre>&lt;decoding failed&gt;</pre>"
        return AnyView(HTMLWebView(html: html))
    }
}

private struct HTMLWebView: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = false
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(html, baseURL: nil)
    }
}
#endif
