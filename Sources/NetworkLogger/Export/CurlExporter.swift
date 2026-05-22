import Foundation

public enum CurlExporter {
    public static func string(for event: NetworkEvent) -> String {
        let request = event.request
        var components: [String] = ["curl -v"]

        if request.httpMethod.uppercased() != "GET" {
            components.append("-X \(request.httpMethod)")
        }

        let sortedHeaders = request.headers.sorted { $0.key < $1.key }
        for (key, value) in sortedHeaders {
            let escapedValue = value.replacingOccurrences(of: "\"", with: "\\\"")
            components.append("-H \"\(key): \(escapedValue)\"")
        }

        if let body = request.body?.text() {
            var escaped = body.replacingOccurrences(of: "\\\"", with: "\\\\\"")
            escaped = escaped.replacingOccurrences(of: "\"", with: "\\\"")
            components.append("-d \"\(escaped)\"")
        }

        for (user, password) in request.credentials.sorted(by: { $0.key < $1.key }) {
            components.append("-u \(user):\(password)")
        }

        if !request.cookies.isEmpty {
            let cookieString = request.cookies
                .map { "\($0.name)=\($0.value)" }
                .joined(separator: "; ")
            components.append("-b \"\(cookieString)\"")
        }

        components.append("\"\(request.url.absoluteString)\"")
        return components.joined(separator: " \\\n\t")
    }

    public static func string(for events: [NetworkEvent]) -> String {
        events.map(string(for:)).joined(separator: "\n\n")
    }
}
