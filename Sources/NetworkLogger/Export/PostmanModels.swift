import Foundation

struct PostmanCollection: Codable, Sendable {
    let info: PostmanInfo
    let item: [PostmanItem]
}

struct PostmanInfo: Codable, Sendable {
    let _postman_id: String
    let name: String
    let schema: String
}

struct PostmanItem: Codable, Sendable {
    let name: String
    var item: [PostmanItem]?
    var request: PostmanRequest?
    var response: [PostmanResponse]?
}

struct PostmanRequest: Codable, Sendable {
    let method: String
    let header: [PostmanHeader]
    let body: PostmanBody?
    let url: PostmanURL
    let description: String?
}

struct PostmanResponse: Codable, Sendable {
    let name: String
    let originalRequest: PostmanRequest
    let status: String
    let code: Int
    let _postman_previewlanguage: String?
    let header: [PostmanHeader]
    let cookie: [PostmanCookie]
    let body: String?
}

struct PostmanHeader: Codable, Sendable {
    let key: String
    let value: String
}

struct PostmanCookie: Codable, Sendable {
    let name: String
    let value: String
    let domain: String?
    let path: String?
}

struct PostmanBody: Codable, Sendable {
    let mode: String
    let raw: String
}

struct PostmanURL: Codable, Sendable {
    let raw: String
    let `protocol`: String
    let host: [String]
    let path: [String]
    let query: [PostmanQuery]?
}

struct PostmanQuery: Codable, Sendable {
    let key: String
    let value: String
}
