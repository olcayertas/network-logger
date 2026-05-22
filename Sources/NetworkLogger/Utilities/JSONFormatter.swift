import Foundation

public enum JSONFormatter {
    public static func prettyPrint(_ data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: data, options: []) else {
            return nil
        }
        guard let pretty = try? JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        ) else {
            return nil
        }
        return String(data: pretty, encoding: .utf8)
    }
}
