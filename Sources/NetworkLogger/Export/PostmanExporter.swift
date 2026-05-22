import Foundation

public enum PostmanExporter {
    public static func collection(
        name: String,
        from events: [NetworkEvent]
    ) -> Data {
        let info = PostmanInfo(
            _postman_id: name,
            name: name,
            schema: "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
        )

        let items = events.compactMap(makeItem(from:))
        let collection = PostmanCollection(info: info, item: items)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(collection)) ?? Data()
    }

    private static func makeItem(from event: NetworkEvent) -> PostmanItem? {
        let url = event.request.url
        guard let scheme = url.scheme, let host = url.host else { return nil }

        let headers = event.request.headers.map { PostmanHeader(key: $0.key, value: $0.value) }
        let rawBody = event.request.body?.text() ?? ""

        let pathComponents = url.pathComponents.filter { $0 != "/" }
        let hostComponents = host.split(separator: ".").map(String.init)
        let query: [PostmanQuery]? = url.query?.split(separator: "&").compactMap { pair in
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return nil }
            return PostmanQuery(key: parts[0], value: parts[1])
        }

        let postmanURL = PostmanURL(
            raw: url.absoluteString,
            protocol: scheme,
            host: hostComponents,
            path: pathComponents,
            query: query
        )
        let postmanBody = event.request.body.map { _ in
            PostmanBody(mode: "raw", raw: rawBody)
        }
        let postmanRequest = PostmanRequest(
            method: event.request.httpMethod,
            header: headers.sorted { $0.key < $1.key },
            body: postmanBody,
            url: postmanURL,
            description: nil
        )

        let responseHeaders = (event.response?.headers ?? [:])
            .map { PostmanHeader(key: $0.key, value: $0.value) }
            .sorted { $0.key < $1.key }
        let postmanResponse = event.response.map { response in
            PostmanResponse(
                name: url.absoluteString,
                originalRequest: postmanRequest,
                status: "",
                code: response.statusCode,
                _postman_previewlanguage: previewLanguage(for: response.headers["Content-Type"]),
                header: responseHeaders,
                cookie: [],
                body: response.body?.text() ?? ""
            )
        }

        let dateFormatter = ISO8601DateFormatter()
        let name = "\(dateFormatter.string(from: event.startDate)) — \(url.absoluteString)"
        return PostmanItem(
            name: name,
            item: nil,
            request: postmanRequest,
            response: postmanResponse.map { [$0] }
        )
    }

    private static func previewLanguage(for contentType: String?) -> String? {
        guard let contentType = contentType?.lowercased() else { return nil }
        if contentType.contains("json") { return "json" }
        if contentType.contains("xml") { return "xml" }
        if contentType.contains("html") { return "html" }
        return "text"
    }
}
