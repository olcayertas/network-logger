import Foundation

/// Resolves the JWT (if any) that should be surfaced as a badge next to a header row.
///
/// The decision encodes the JWT badge contract that `HeadersSection` renders:
///
/// 1. Prefer a pre-decoded JWT captured at sanitize time. This is how the badge
///    survives the default `headerRedactor` replacing the raw value with
///    `•••redacted•••`.
/// 2. Otherwise, parse the visible value live — stripping a leading `Bearer ` for
///    Authorization-style headers.
///
/// Lives outside the SwiftUI view so the contract is testable without spinning up the UI.
enum HeaderJWTResolver {
    static func jwt(forHeader key: String, value: String?, decoded: [String: JWT]) -> JWT? {
        if let cached = decoded[key.lowercased()] {
            return cached
        }
        guard let value else { return nil }
        switch key.lowercased() {
        case "authorization", "proxy-authorization":
            return JWTDetector.jwtFromAuthorizationHeader(value)
        default:
            return JWTDetector.firstJWT(in: value)
        }
    }
}
