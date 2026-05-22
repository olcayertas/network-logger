#if os(iOS)
import Perception
import SwiftUI
import UIKit

struct BodyDetailView: View {
    let payload: BodyData
    let title: String
    @State private var searchText: String = ""
    @State private var formatted: String = ""
    @State private var isJSON: Bool = false
    @State private var showCopiedAlert = false
    @Environment(\.networkLoggerAppearance) private var appearance
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        WithPerceptionTracking {
            ScrollView {
                Text(attributedBody)
                    .font(.system(size: appearance.bodyFontSize, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .textSelection(.enabled)
                    .onTapGesture {
                        UIPasteboard.general.string = formatted
                        showCopiedAlert = true
                    }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: Text("Find in body"))
            .task(id: payload) {
                if let pretty = JSONFormatter.prettyPrint(payload.data) {
                    formatted = pretty
                    isJSON = true
                } else if let text = payload.text() {
                    formatted = text
                    isJSON = false
                } else {
                    formatted = "<binary \(payload.byteCount) bytes>"
                    isJSON = false
                }
            }
            .alert("Copied", isPresented: $showCopiedAlert) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private var attributedBody: AttributedString {
        var attributed: AttributedString
        if isJSON {
            attributed = JSONHighlighter.attributed(
                formatted,
                theme: appearance.syntaxTheme(for: colorScheme)
            )
        } else {
            attributed = AttributedString(formatted)
        }
        applySearchHighlight(to: &attributed)
        return attributed
    }

    private func applySearchHighlight(to attributed: inout AttributedString) {
        guard !searchText.isEmpty else { return }
        var searchStart = formatted.startIndex
        while let range = formatted.range(
            of: searchText,
            options: .caseInsensitive,
            range: searchStart..<formatted.endIndex
        ) {
            if let attrRange = Range(range, in: attributed) {
                attributed[attrRange].backgroundColor = .yellow.opacity(0.45)
                attributed[attrRange].foregroundColor = .black
            }
            searchStart = range.upperBound
        }
    }
}
#endif
