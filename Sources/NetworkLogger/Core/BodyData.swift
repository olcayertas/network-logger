import Foundation

public struct BodyData: Sendable, Equatable, Hashable {
    public let data: Data
    public let originalSize: Int64
    public let truncated: Bool
    public let contentType: String?

    public init(
        data: Data,
        originalSize: Int64? = nil,
        truncated: Bool = false,
        contentType: String? = nil
    ) {
        self.data = data
        self.originalSize = originalSize ?? Int64(data.count)
        self.truncated = truncated
        self.contentType = contentType
    }

    public var byteCount: Int { data.count }

    public func text(encoding: String.Encoding = .utf8) -> String? {
        String(data: data, encoding: encoding)
    }
}
