#if os(iOS)
import SwiftUI
import UIKit

struct BodyDetailView: View {
    let payload: BodyData
    let title: String
    @State private var searchText: String = ""
    @State private var formatted: String = ""
    @State private var showCopiedAlert = false

    var body: some View {
        ScrollView {
            HighlightedText(text: formatted, highlight: searchText)
                .font(.system(.body, design: .monospaced))
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
            formatted = JSONFormatter.prettyPrint(payload.data) ?? payload.text() ?? "<binary \(payload.byteCount) bytes>"
        }
        .alert("Copied", isPresented: $showCopiedAlert) {
            Button("OK", role: .cancel) {}
        }
    }
}

private struct HighlightedText: View {
    let text: String
    let highlight: String

    var body: some View {
        if highlight.isEmpty {
            Text(text)
        } else {
            attributed
        }
    }

    private var attributed: Text {
        var ranges: [Range<String.Index>] = []
        var searchStart = text.startIndex
        while let range = text.range(of: highlight, options: .caseInsensitive, range: searchStart..<text.endIndex) {
            ranges.append(range)
            searchStart = range.upperBound
        }

        guard !ranges.isEmpty else { return Text(text) }
        var attributedString = AttributedString(text)
        for range in ranges {
            if let attrRange = Range(range, in: attributedString) {
                attributedString[attrRange].backgroundColor = .yellow.opacity(0.45)
                attributedString[attrRange].foregroundColor = .black
            }
        }
        return Text(attributedString)
    }
}
#endif
