import Foundation

public struct NetworkResponseSnapshot: Sendable, Equatable, Hashable, Codable {
    public var statusCode: Int
    public var headers: [String: String]
    public var body: BodyData?
    public var mimeType: String?
    public var textEncodingName: String?

    public init(
        statusCode: Int,
        headers: [String: String] = [:],
        body: BodyData? = nil,
        mimeType: String? = nil,
        textEncodingName: String? = nil
    ) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
        self.mimeType = mimeType
        self.textEncodingName = textEncodingName
    }

    public init(
        httpResponse: HTTPURLResponse,
        body: BodyData? = nil
    ) {
        self.statusCode = httpResponse.statusCode
        self.headers = httpResponse.allHeaderFields.reduce(into: [String: String]()) { result, pair in
            if let key = pair.key as? String {
                result[key] = "\(pair.value)"
            }
        }
        self.body = body
        self.mimeType = httpResponse.mimeType
        self.textEncodingName = httpResponse.textEncodingName
    }
}
