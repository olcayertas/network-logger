#if os(iOS)
import Perception
import SwiftUI

struct BodyDetailView: View {
    let payload: BodyData
    let title: String
    let mimeType: String?
    @State private var searchText: String = ""
    @Environment(\.networkLoggerAppearance) private var appearance
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.bodyViewers) private var extraViewers

    init(payload: BodyData, title: String, mimeType: String? = nil) {
        self.payload = payload
        self.title = title
        self.mimeType = mimeType ?? payload.contentType
    }

    var body: some View {
        WithPerceptionTracking {
            let viewer = BodyViewerResolver.resolve(extras: extraViewers, for: payload, mimeType: mimeType)
            let context = BodyViewerContext(
                searchText: searchText,
                bodyFontSize: appearance.bodyFontSize,
                syntaxTheme: appearance.syntaxTheme(for: colorScheme),
                colorScheme: colorScheme
            )
            viewer.makeView(body: payload, mimeType: mimeType, context: context)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $searchText, prompt: Text("Find in body"))
        }
    }
}
#endif
