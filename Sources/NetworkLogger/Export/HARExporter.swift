import Foundation

public enum HARExporter {
    public static func har(from events: [NetworkEvent], creator: String = "NetworkLogger") -> Data {
        let entries = events.map(makeEntry(from:))
        let har = HARDocument(
            log: HARLog(
                version: "1.2",
                creator: HARCreator(name: creator, version: "1.0"),
                entries: entries
            )
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(har)) ?? Data()
    }

    private static func makeEntry(from event: NetworkEvent) -> HAREntry {
        let request = HARRequest(
            method: event.request.httpMethod,
            url: event.request.url.absoluteString,
            httpVersion: "HTTP/1.1",
            headers: event.request.headers.sorted { $0.key < $1.key }.map { HARNameValue(name: $0.key, value: $0.value) },
            queryString: queryItems(from: event.request.url),
            postData: postData(from: event.request),
            headersSize: -1,
            bodySize: Int(event.request.body?.originalSize ?? -1)
        )
        let response = HARResponse(
            status: event.response?.statusCode ?? 0,
            statusText: "",
            httpVersion: "HTTP/1.1",
            headers: (event.response?.headers ?? [:]).sorted { $0.key < $1.key }.map { HARNameValue(name: $0.key, value: $0.value) },
            cookies: [],
            content: HARContent(
                size: Int(event.response?.body?.originalSize ?? -1),
                mimeType: event.response?.headers["Content-Type"] ?? event.response?.mimeType ?? "",
                text: event.response?.body?.text()
            ),
            redirectURL: "",
            headersSize: -1,
            bodySize: Int(event.response?.body?.originalSize ?? -1)
        )
        let timings = HARTimings(
            send: 0,
            wait: 0,
            receive: 0
        )
        return HAREntry(
            startedDateTime: ISO8601DateFormatter().string(from: event.startDate),
            time: (event.metrics.duration ?? 0) * 1000,
            request: request,
            response: response,
            cache: HARCache(),
            timings: timings
        )
    }

    private static func queryItems(from url: URL) -> [HARNameValue] {
        guard let query = url.query else { return [] }
        return query.split(separator: "&").compactMap { pair in
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return nil }
            return HARNameValue(name: parts[0], value: parts[1])
        }
    }

    private static func postData(from request: NetworkRequestSnapshot) -> HARPostData? {
        guard let body = request.body, !body.data.isEmpty else { return nil }
        return HARPostData(
            mimeType: request.headers["Content-Type"] ?? "application/octet-stream",
            text: body.text() ?? ""
        )
    }
}

private struct HARDocument: Codable {
    let log: HARLog
}

private struct HARLog: Codable {
    let version: String
    let creator: HARCreator
    let entries: [HAREntry]
}

private struct HARCreator: Codable {
    let name: String
    let version: String
}

private struct HAREntry: Codable {
    let startedDateTime: String
    let time: Double
    let request: HARRequest
    let response: HARResponse
    let cache: HARCache
    let timings: HARTimings
}

private struct HARRequest: Codable {
    let method: String
    let url: String
    let httpVersion: String
    let headers: [HARNameValue]
    let queryString: [HARNameValue]
    let postData: HARPostData?
    let headersSize: Int
    let bodySize: Int
}

private struct HARResponse: Codable {
    let status: Int
    let statusText: String
    let httpVersion: String
    let headers: [HARNameValue]
    let cookies: [HARNameValue]
    let content: HARContent
    let redirectURL: String
    let headersSize: Int
    let bodySize: Int
}

private struct HARContent: Codable {
    let size: Int
    let mimeType: String
    let text: String?
}

private struct HARPostData: Codable {
    let mimeType: String
    let text: String
}

private struct HARCache: Codable {}

private struct HARTimings: Codable {
    let send: Double
    let wait: Double
    let receive: Double
}

private struct HARNameValue: Codable {
    let name: String
    let value: String
}
