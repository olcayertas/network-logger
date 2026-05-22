import Foundation

public enum PlainTextExporter {
    public static func text(for event: NetworkEvent) -> String {
        var lines: [String] = []
        lines.append("*** Overview ***")
        lines.append("URL: \(event.request.url.absoluteString)")
        lines.append("Method: \(event.request.httpMethod)")
        if let response = event.response {
            lines.append("Status: \(response.statusCode)")
        } else {
            lines.append("Status: -")
        }
        if let duration = event.metrics.duration {
            lines.append("Duration: \(String(format: "%.2f", duration * 1000)) ms")
        }
        if let error = event.error {
            lines.append("Error: \(error.message) [code \(error.code), domain \(error.domain)]")
        }
        lines.append("")
        lines.append("*** Request Headers ***")
        lines.append(format(headers: event.request.headers))
        lines.append("")
        lines.append("*** Request Body ***")
        lines.append(event.request.body?.text() ?? "-")
        lines.append("")
        lines.append("*** Response Headers ***")
        lines.append(format(headers: event.response?.headers ?? [:]))
        lines.append("")
        lines.append("*** Response Body ***")
        lines.append(event.response?.body?.text() ?? "-")
        lines.append("")
        lines.append(String(repeating: "-", count: 60))
        return lines.joined(separator: "\n")
    }

    public static func text(for events: [NetworkEvent]) -> String {
        events.map(text(for:)).joined(separator: "\n\n")
    }

    private static func format(headers: [String: String]) -> String {
        guard !headers.isEmpty else { return "-" }
        return headers
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "\n")
    }
}
