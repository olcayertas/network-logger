import Foundation

/// Scans a string for JWT-shaped substrings.
///
/// The pattern requires the canonical base64url-of-`{"` prefix `eyJ`, three
/// dot-separated parts, and a non-empty header & payload. The signature part can be
/// empty (`alg=none` tokens). After regex match we attempt a full decode via `JWT(_:)`
/// to filter out random `eyJ…` substrings that aren't actual JWTs.
public enum JWTDetector {
    private static let pattern = #"eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*"#

    private static let regex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: pattern)
    }()

    /// First valid JWT found in `string`, or `nil`.
    public static func firstJWT(in string: String) -> JWT? {
        guard let regex else { return nil }
        let ns = string as NSString
        let range = NSRange(location: 0, length: ns.length)
        var match: JWT?
        regex.enumerateMatches(in: string, options: [], range: range) { result, _, stop in
            guard let r = result?.range else { return }
            let candidate = ns.substring(with: r)
            if let jwt = JWT(candidate) {
                match = jwt
                stop.pointee = true
            }
        }
        return match
    }

    /// All valid JWTs in `string`, each paired with its source substring.
    public static func allJWTs(in string: String) -> [(substring: String, jwt: JWT)] {
        guard let regex else { return [] }
        let ns = string as NSString
        let range = NSRange(location: 0, length: ns.length)
        var matches: [(String, JWT)] = []
        regex.enumerateMatches(in: string, options: [], range: range) { result, _, _ in
            guard let r = result?.range else { return }
            let candidate = ns.substring(with: r)
            if let jwt = JWT(candidate) {
                matches.append((candidate, jwt))
            }
        }
        return matches
    }

    /// Parses an `Authorization` header value — strips a leading `Bearer ` (case-insensitive)
    /// and tries to decode the rest as a JWT.
    public static func jwtFromAuthorizationHeader(_ value: String) -> JWT? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        let candidate: String
        if let range = trimmed.range(of: "bearer ", options: [.caseInsensitive, .anchored]) {
            candidate = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        } else {
            candidate = trimmed
        }
        return JWT(candidate)
    }
}
