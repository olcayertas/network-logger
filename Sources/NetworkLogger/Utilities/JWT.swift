import Foundation

/// A decoded JSON Web Token (RFC 7519). Pure structural decode — **no signature
/// verification** is performed (we don't have the key material, and signature checking
/// is outside the scope of a debugging viewer). The validity banner is informational
/// only and reflects only `exp` / `nbf` time-window checks.
public struct JWT: Sendable, Equatable, Hashable, Codable {
    public let headerPrettyJSON: String
    public let payloadPrettyJSON: String
    public let signature: Data

    /// The three dot-separated base64url segments as they appeared in the input.
    public let rawHeader: String
    public let rawPayload: String
    public let rawSignature: String

    public let claims: Claims

    public init?(_ candidate: String) {
        let parts = candidate.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        let h = String(parts[0]), p = String(parts[1]), s = String(parts[2])
        guard let headerData = Self.base64urlDecode(h),
              let payloadData = Self.base64urlDecode(p),
              let signatureData = Self.base64urlDecode(s, allowEmpty: true) else { return nil }
        guard let headerJSON = try? JSONSerialization.jsonObject(with: headerData),
              let payloadJSON = try? JSONSerialization.jsonObject(with: payloadData),
              let headerDict = headerJSON as? [String: Any],
              let payloadDict = payloadJSON as? [String: Any] else { return nil }
        self.rawHeader = h
        self.rawPayload = p
        self.rawSignature = s
        self.signature = signatureData
        self.headerPrettyJSON = Self.prettyJSON(headerDict)
        self.payloadPrettyJSON = Self.prettyJSON(payloadDict)
        self.claims = Claims(header: headerDict, payload: payloadDict)
    }

    /// Standard claims extracted from the decoded header & payload.
    public struct Claims: Sendable, Equatable, Hashable, Codable {
        public let alg: String?
        public let typ: String?
        public let kid: String?
        public let iss: String?
        public let sub: String?
        public let aud: [String]
        public let exp: Date?
        public let iat: Date?
        public let nbf: Date?
        public let jti: String?
        public let customKeys: [String]   // payload keys outside the standard set

        init(header: [String: Any], payload: [String: Any]) {
            self.alg = header["alg"] as? String
            self.typ = header["typ"] as? String
            self.kid = header["kid"] as? String
            self.iss = payload["iss"] as? String
            self.sub = payload["sub"] as? String
            if let array = payload["aud"] as? [String] {
                self.aud = array
            } else if let single = payload["aud"] as? String {
                self.aud = [single]
            } else {
                self.aud = []
            }
            self.exp = (payload["exp"] as? Double).map(Date.init(timeIntervalSince1970:))
            self.iat = (payload["iat"] as? Double).map(Date.init(timeIntervalSince1970:))
            self.nbf = (payload["nbf"] as? Double).map(Date.init(timeIntervalSince1970:))
            self.jti = payload["jti"] as? String
            let standardKeys: Set<String> = ["iss", "sub", "aud", "exp", "iat", "nbf", "jti"]
            self.customKeys = payload.keys.filter { !standardKeys.contains($0) }.sorted()
        }
    }

    public enum ValidityStatus: Sendable, Equatable, Hashable, Codable {
        case valid
        case expired(since: Date)
        case notYetValid(until: Date)
    }

    public func validity(now: Date = Date()) -> ValidityStatus {
        if let exp = claims.exp, now > exp { return .expired(since: exp) }
        if let nbf = claims.nbf, now < nbf { return .notYetValid(until: nbf) }
        return .valid
    }

    // MARK: - base64url

    static func base64urlDecode(_ string: String, allowEmpty: Bool = false) -> Data? {
        if string.isEmpty { return allowEmpty ? Data() : nil }
        var s = string.replacingOccurrences(of: "-", with: "+")
                       .replacingOccurrences(of: "_", with: "/")
        // Pad to multiple of 4
        let remainder = s.count % 4
        if remainder > 0 { s += String(repeating: "=", count: 4 - remainder) }
        return Data(base64Encoded: s)
    }

    static func prettyJSON(_ object: Any) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        ),
        let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }
}
