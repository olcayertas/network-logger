#if os(iOS)
import SwiftUI
import UIKit
import NetworkLogger

/// Renders an image body (PNG, JPEG, HEIC, GIF, WebP — anything `UIImage(data:)` decodes)
/// with pinch-to-zoom inside a `ScrollView`. Falls through if the data fails to decode.
public struct ImageBodyViewer: BodyViewer {
    public init() {}

    public func canHandle(mimeType: String?, body: BodyData) -> Bool {
        if let mimeType, mimeType.lowercased().hasPrefix("image/") {
            return UIImage(data: body.data) != nil
        }
        return UIImage(data: body.data) != nil && looksLikeImageMagic(body.data)
    }

    public func makeView(body: BodyData, mimeType: String?, context: BodyViewerContext) -> AnyView {
        guard let image = UIImage(data: body.data) else { return AnyView(EmptyView()) }
        return AnyView(
            ScrollView([.horizontal, .vertical]) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            }
        )
    }

    /// Quick magic-number sniff so we don't accidentally claim arbitrary binary blobs.
    private func looksLikeImageMagic(_ data: Data) -> Bool {
        guard data.count >= 4 else { return false }
        let bytes = data.prefix(8)
        // PNG (89 50 4E 47), JPEG (FF D8 FF), GIF (47 49 46), HEIC (..ftyp), WebP (52 49 46 46 .. 57 45 42 50)
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return true }
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) { return true }
        if bytes.starts(with: [0x47, 0x49, 0x46]) { return true }
        if bytes.count >= 12, bytes[bytes.startIndex.advanced(by: 4)..<bytes.startIndex.advanced(by: 8)].elementsEqual([0x66, 0x74, 0x79, 0x70]) {
            return true // ftyp box → HEIC/HEIF
        }
        if bytes.starts(with: [0x52, 0x49, 0x46, 0x46]) { return true } // RIFF (WebP)
        return false
    }
}
#endif
