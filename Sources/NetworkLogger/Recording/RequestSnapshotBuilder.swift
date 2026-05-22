import Foundation

enum RequestSnapshotBuilder {
    static func make(
        from request: URLRequest,
        session: URLSession? = nil
    ) -> NetworkRequestSnapshot {
        let url = request.url ?? URL(string: "about:blank")!
        let method = request.httpMethod ?? "GET"
        var headers = request.allHTTPHeaderFields ?? [:]

        if let additional = session?.configuration.httpAdditionalHeaders {
            for (rawKey, rawValue) in additional {
                guard let key = rawKey as? String, key.lowercased() != "cookie" else { continue }
                guard headers[key] == nil else { continue }
                if let value = rawValue as? String {
                    headers[key] = value
                } else {
                    headers[key] = "\(rawValue)"
                }
            }
        }

        let body: BodyData? = request.httpBody.map {
            BodyData(
                data: $0,
                originalSize: Int64($0.count),
                truncated: false,
                contentType: headers["Content-Type"]
            )
        }

        let credentials = collectCredentials(for: url, session: session)
        let cookies = collectCookies(for: url, session: session)

        return NetworkRequestSnapshot(
            url: url,
            httpMethod: method,
            headers: headers,
            body: body,
            credentials: credentials,
            cookies: cookies
        )
    }

    private static func collectCredentials(
        for url: URL,
        session: URLSession?
    ) -> [String: String] {
        guard let storage = session?.configuration.urlCredentialStorage,
              let host = url.host,
              let port = url.port,
              let scheme = url.scheme else {
            return [:]
        }
        let space = URLProtectionSpace(
            host: host,
            port: port,
            protocol: scheme,
            realm: host,
            authenticationMethod: NSURLAuthenticationMethodHTTPBasic
        )
        var pairs: [String: String] = [:]
        if let credentials = storage.credentials(for: space)?.values {
            for credential in credentials {
                if let user = credential.user, let password = credential.password {
                    pairs[user] = password
                }
            }
        }
        return pairs
    }

    private static func collectCookies(
        for url: URL,
        session: URLSession?
    ) -> [HTTPCookieSnapshot] {
        guard let session, session.configuration.httpShouldSetCookies else { return [] }
        guard let storage = session.configuration.httpCookieStorage,
              let cookies = storage.cookies(for: url) else { return [] }
        return cookies.compactMap(HTTPCookieSnapshot.init)
    }
}
