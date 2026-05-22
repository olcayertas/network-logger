#if os(iOS)
import SwiftUI
import PDFKit
import NetworkLogger

/// Renders a PDF body via `PDFKit.PDFView`. Accepts `application/pdf` MIME type and
/// also sniffs the leading `%PDF-` magic when MIME type is missing or mislabelled.
public struct PDFBodyViewer: BodyViewer {
    public init() {}

    public func canHandle(mimeType: String?, body: BodyData) -> Bool {
        if let mimeType, mimeType.lowercased().contains("pdf") { return true }
        let magic = body.data.prefix(5)
        return magic.elementsEqual([0x25, 0x50, 0x44, 0x46, 0x2D])  // %PDF-
    }

    public func makeView(body: BodyData, mimeType: String?, context: BodyViewerContext) -> AnyView {
        guard let document = PDFDocument(data: body.data) else { return AnyView(EmptyView()) }
        return AnyView(PDFKitView(document: document))
    }
}

private struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}
#endif
