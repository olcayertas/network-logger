import Foundation

public enum Redaction {
    public static let defaultSensitiveHeaders: Set<String> = [
        "authorization",
        "cookie",
        "set-cookie",
        "proxy-authorization",
        "x-api-key",
    ]

    public static func makeHeaderRedactor(
        sensitive: Set<String> = defaultSensitiveHeaders,
        replacement: String = "•••redacted•••"
    ) -> @Sendable ([String: String]) -> [String: String] {
        let lowercased = Set(sensitive.map { $0.lowercased() })
        return { headers in
            var redacted: [String: String] = [:]
            for (key, value) in headers {
                if lowercased.contains(key.lowercased()) {
                    redacted[key] = replacement
                } else {
                    redacted[key] = value
                }
            }
            return redacted
        }
    }
}
