#if os(iOS)
import SwiftUI
import NetworkLogger

/// Convenience entry point for the media viewers bundle.
///
/// ```swift
/// import NetworkLoggerMediaViewers
///
/// NetworkLoggerView(logger: logger, bodyViewers: MediaBodyViewers.all)
/// ```
///
/// Lives in a separate SPM product so consumers that only need the JSON/text built-ins
/// don't link `WebKit` or `PDFKit`.
public enum MediaBodyViewers {
    /// Image, HTML, and PDF viewers in the recommended resolution order.
    public static let all: [any BodyViewer] = [
        ImageBodyViewer(),
        PDFBodyViewer(),
        HTMLBodyViewer(),
    ]
}
#endif
