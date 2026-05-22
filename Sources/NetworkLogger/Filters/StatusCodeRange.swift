import Foundation

/// Inclusive integer range used by `SearchToken.statusCode`.
///
/// Parsable spellings (mirrors Pulse's `ConsoleSearchToken.parseStatusCodeRange`):
/// - `200` → `200...200`
/// - `2XX` (case-insensitive) → `200...299`
/// - `200..<300` (half-open) → `200...299`
/// - `200...299` (closed) → `200...299`
public struct StatusCodeRange: Sendable, Hashable, Codable {
    public let lower: Int
    public let upper: Int

    public init(_ closed: ClosedRange<Int>) {
        self.lower = closed.lowerBound
        self.upper = closed.upperBound
    }

    public init(lower: Int, upper: Int) {
        self.lower = min(lower, upper)
        self.upper = max(lower, upper)
    }

    public var closedRange: ClosedRange<Int> { lower...upper }

    public func contains(_ code: Int) -> Bool { closedRange.contains(code) }

    public var displayLabel: String {
        if lower == upper { return "\(lower)" }
        if lower / 100 == upper / 100, lower % 100 == 0, upper % 100 == 99 {
            return "\(lower / 100)XX"
        }
        return "\(lower)–\(upper)"
    }
}
