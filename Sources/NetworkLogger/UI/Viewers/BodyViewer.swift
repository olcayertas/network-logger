#if os(iOS)
import SwiftUI

/// Renders a captured request/response body in `BodyDetailView`.
///
/// `NetworkLogger` ships two default viewers in its UI: `JSONBodyViewer` (pretty-prints +
/// syntax-highlights JSON) and `TextBodyViewer` (UTF-8 text fallback, with a `<binary>`
/// placeholder when decoding fails). Additional viewers — for images, HTML, PDFs, or
/// custom payloads — can be plugged in by passing them to
/// `NetworkLoggerView(logger:bodyViewers:)`; the resolver consults them in order before
/// falling back to the built-ins.
@MainActor
public protocol BodyViewer: Sendable {
    /// Whether this viewer can render the given body. The first viewer whose
    /// `canHandle(...)` returns `true` (extras first, then JSON, then text) wins.
    func canHandle(mimeType: String?, body: BodyData) -> Bool

    /// Builds the SwiftUI content for the body. Type-erased to `AnyView` so the chain can
    /// be stored in a heterogeneous `[any BodyViewer]`.
    func makeView(body: BodyData, mimeType: String?, context: BodyViewerContext) -> AnyView
}

/// Read-only context handed to each viewer: the current search-bar text and the
/// active appearance/color scheme.
public struct BodyViewerContext: Sendable {
    public let searchText: String
    public let bodyFontSize: Double
    public let syntaxTheme: SyntaxTheme
    public let colorScheme: ColorScheme

    public init(searchText: String, bodyFontSize: Double, syntaxTheme: SyntaxTheme, colorScheme: ColorScheme) {
        self.searchText = searchText
        self.bodyFontSize = bodyFontSize
        self.syntaxTheme = syntaxTheme
        self.colorScheme = colorScheme
    }
}

/// Picks the first matching viewer from `extras`, falling back to JSON then plain text.
enum BodyViewerResolver {
    @MainActor
    static func resolve(extras: [any BodyViewer], for body: BodyData, mimeType: String?) -> any BodyViewer {
        for viewer in extras where viewer.canHandle(mimeType: mimeType, body: body) {
            return viewer
        }
        if JSONBodyViewer.shared.canHandle(mimeType: mimeType, body: body) {
            return JSONBodyViewer.shared
        }
        return TextBodyViewer.shared
    }
}

private struct BodyViewersKey: EnvironmentKey {
    static let defaultValue: [any BodyViewer] = []
}

extension EnvironmentValues {
    /// Extra viewers contributed by `NetworkLoggerView(logger:bodyViewers:)`. Consulted
    /// ahead of the built-in JSON/text fallback by `BodyViewerResolver`.
    var bodyViewers: [any BodyViewer] {
        get { self[BodyViewersKey.self] }
        set { self[BodyViewersKey.self] = newValue }
    }
}

/// Helper that applies case-insensitive search highlighting to an `AttributedString`.
enum BodyViewerSearchHighlight {
    static func apply(searchText: String, in attributed: inout AttributedString, source: String) {
        guard !searchText.isEmpty else { return }
        var cursor = source.startIndex
        while let range = source.range(of: searchText, options: .caseInsensitive, range: cursor..<source.endIndex) {
            if let attrRange = Range(range, in: attributed) {
                attributed[attrRange].backgroundColor = .yellow.opacity(0.45)
                attributed[attrRange].foregroundColor = .black
            }
            cursor = range.upperBound
        }
    }
}
#endif
