import Foundation

public struct NetworkRequestSnapshot: Sendable, Equatable, Hashable {
    public let url: URL
    public let httpMethod: String
    public let headers: [String: String]
    public let body: BodyData?
    public let credentials: [String: String]
    public let cookies: [HTTPCookieSnapshot]

    public init(
        url: URL,
        httpMethod: String,
        headers: [String: String] = [:],
        body: BodyData? = nil,
        credentials: [String: String] = [:],
        cookies: [HTTPCookieSnapshot] = []
    ) {
        self.url = url
        self.httpMethod = httpMethod
        self.headers = headers
        self.body = body
        self.credentials = credentials
        self.cookies = cookies
    }
}

public extension NetworkRequestSnapshot {
    var host: String? { url.host }
    var port: Int? { url.port }
    var scheme: String? { url.scheme }
}

public struct HTTPCookieSnapshot: Sendable, Equatable, Hashable {
    public let name: String
    public let value: String
    public let domain: String?
    public let path: String?
    public let expiresDate: Date?

    public init(
        name: String,
        value: String,
        domain: String? = nil,
        path: String? = nil,
        expiresDate: Date? = nil
    ) {
        self.name = name
        self.value = value
        self.domain = domain
        self.path = path
        self.expiresDate = expiresDate
    }

    public init?(_ cookie: HTTPCookie) {
        guard !cookie.name.isEmpty else { return nil }
        self.name = cookie.name
        self.value = cookie.value
        self.domain = cookie.domain
        self.path = cookie.path
        self.expiresDate = cookie.expiresDate
    }
}
