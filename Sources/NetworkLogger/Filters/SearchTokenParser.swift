import Foundation

/// The result of parsing the user's search-bar input.
public struct ParsedSearch: Sendable, Equatable {
    public var tokens: [SearchToken]
    public var freeText: String

    public init(tokens: [SearchToken] = [], freeText: String = "") {
        self.tokens = tokens
        self.freeText = freeText
    }
}

/// Parses search-bar input into `SearchToken`s + a free-text remainder.
///
/// Grammar (whitespace-separated):
/// - `host:<value>`
/// - `method:<value>` (case-insensitive; canonicalised to uppercase)
/// - `path:<value>`
/// - `statusCode:<n>` | `2XX` | `200..<300` | `200...299` (also accepts `status:` / `code:`)
///
/// Anything that doesn't match a known key (or a `key:value` shape) falls through into
/// `freeText`, so `host:foo cats` produces one token plus `"cats"`.
public enum SearchTokenParser {
    public static func parse(_ input: String) -> ParsedSearch {
        var tokens: [SearchToken] = []
        var freePieces: [String] = []
        for piece in input.split(whereSeparator: \.isWhitespace) {
            let str = String(piece)
            if let token = parsePiece(str) {
                tokens.append(token)
            } else {
                freePieces.append(str)
            }
        }
        return ParsedSearch(tokens: tokens, freeText: freePieces.joined(separator: " "))
    }

    private static func parsePiece(_ piece: String) -> SearchToken? {
        guard let colonIndex = piece.firstIndex(of: ":"), colonIndex != piece.startIndex else {
            return nil
        }
        let key = piece[piece.startIndex..<colonIndex].lowercased()
        let value = String(piece[piece.index(after: colonIndex)...])
        guard !value.isEmpty else { return nil }
        switch key {
        case "host":
            return .host(value)
        case "method":
            return .method(value.uppercased())
        case "path":
            return .path(value)
        case "status", "statuscode", "code":
            return parseStatusCode(value).map(SearchToken.statusCode)
        default:
            return nil
        }
    }

    static func parseStatusCode(_ value: String) -> StatusCodeRange? {
        // 200..<300 (half-open)
        if let range = value.range(of: "..<") {
            let lower = Int(value[..<range.lowerBound].trimmingCharacters(in: .whitespaces))
            let upper = Int(value[range.upperBound...].trimmingCharacters(in: .whitespaces))
            if let lower, let upper, upper > 0 {
                return StatusCodeRange(lower: lower, upper: upper - 1)
            }
            return nil
        }
        // 200...299 (closed)
        if let range = value.range(of: "...") {
            let lower = Int(value[..<range.lowerBound].trimmingCharacters(in: .whitespaces))
            let upper = Int(value[range.upperBound...].trimmingCharacters(in: .whitespaces))
            if let lower, let upper {
                return StatusCodeRange(lower: lower, upper: upper)
            }
            return nil
        }
        // 2XX class
        if value.count == 3,
           let firstChar = value.first,
           let prefix = Int(String(firstChar)),
           value.dropFirst().lowercased() == "xx" {
            let lower = prefix * 100
            return StatusCodeRange(lower: lower, upper: lower + 99)
        }
        // 200 single
        if let single = Int(value) {
            return StatusCodeRange(lower: single, upper: single)
        }
        return nil
    }
}
