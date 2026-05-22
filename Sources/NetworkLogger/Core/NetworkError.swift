import Foundation

public struct NetworkError: Sendable, Equatable, Hashable, Error, Codable {
    public let code: Int
    public let domain: String
    public let message: String

    public init(code: Int, domain: String, message: String) {
        self.code = code
        self.domain = domain
        self.message = message
    }

    public init(_ error: Error) {
        let nsError = error as NSError
        self.code = nsError.code
        self.domain = nsError.domain
        self.message = error.localizedDescription
    }
}
