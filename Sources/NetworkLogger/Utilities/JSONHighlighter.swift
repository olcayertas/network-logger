#if canImport(SwiftUI)
import Foundation
import SwiftUI

/// Token-level syntax highlighter for pretty-printed JSON strings.
///
/// Walks the source once (O(n)) classifying each region into one of
/// `SyntaxTheme`'s categories and stamps the appropriate `foregroundColor` onto
/// the returned `AttributedString`. Whitespace and unrecognised text keep the
/// default foreground.
///
/// Tolerant by design: unbalanced quotes, truncated bodies, or non-JSON input
/// fall through to plain unstyled output so the view never throws.
enum JSONHighlighter {
    static func attributed(_ source: String, theme: SyntaxTheme) -> AttributedString {
        var output = AttributedString(source)
        let chars = Array(source)
        var index = 0

        while index < chars.count {
            let char = chars[index]

            switch char {
            case "\"":
                let stringRange = scanString(in: chars, startingAt: index)
                let endsAt = stringRange.upperBound
                // Look ahead past whitespace for ':' to distinguish keys from string values.
                let isKey = isFollowedByColon(in: chars, after: endsAt)
                stamp(
                    range: index..<endsAt,
                    color: isKey ? theme.key : theme.string,
                    in: &output,
                    source: source
                )
                index = endsAt

            case "-", "0"..."9":
                let endsAt = scanNumber(in: chars, startingAt: index)
                stamp(range: index..<endsAt, color: theme.number, in: &output, source: source)
                index = endsAt

            case "t", "f":
                if let endsAt = scanKeyword(["true", "false"], in: chars, startingAt: index) {
                    stamp(range: index..<endsAt, color: theme.boolean, in: &output, source: source)
                    index = endsAt
                } else {
                    index += 1
                }

            case "n":
                if let endsAt = scanKeyword(["null"], in: chars, startingAt: index) {
                    stamp(range: index..<endsAt, color: theme.null, in: &output, source: source)
                    index = endsAt
                } else {
                    index += 1
                }

            case "{", "}", "[", "]", ",", ":":
                stamp(range: index..<(index + 1), color: theme.punctuation, in: &output, source: source)
                index += 1

            default:
                index += 1
            }
        }

        return output
    }

    // MARK: - Token scanners

    private static func scanString(in chars: [Character], startingAt start: Int) -> Range<Int> {
        precondition(chars[start] == "\"")
        var index = start + 1
        while index < chars.count {
            let char = chars[index]
            if char == "\\", index + 1 < chars.count {
                index += 2
                continue
            }
            if char == "\"" {
                return start..<(index + 1)
            }
            index += 1
        }
        // Unterminated — colour the rest as a string anyway.
        return start..<chars.count
    }

    private static func scanNumber(in chars: [Character], startingAt start: Int) -> Int {
        var index = start
        if chars[index] == "-" { index += 1 }
        while index < chars.count {
            let char = chars[index]
            if char.isNumber || char == "." || char == "e" || char == "E" || char == "+" || char == "-" {
                index += 1
            } else {
                break
            }
        }
        return index
    }

    private static func scanKeyword(_ keywords: [String], in chars: [Character], startingAt start: Int) -> Int? {
        for keyword in keywords {
            let end = start + keyword.count
            guard end <= chars.count else { continue }
            if String(chars[start..<end]) == keyword {
                return end
            }
        }
        return nil
    }

    private static func isFollowedByColon(in chars: [Character], after index: Int) -> Bool {
        var probe = index
        while probe < chars.count {
            let char = chars[probe]
            if char.isWhitespace {
                probe += 1
                continue
            }
            return char == ":"
        }
        return false
    }

    // MARK: - Attribution

    private static func stamp(
        range: Range<Int>,
        color: Color,
        in attributed: inout AttributedString,
        source: String
    ) {
        guard let start = source.utf16Index(at: range.lowerBound),
              let end = source.utf16Index(at: range.upperBound),
              let attrRange = Range(NSRange(start..<end, in: source), in: attributed)
        else { return }
        attributed[attrRange].foregroundColor = color
    }
}

private extension String {
    /// Converts an offset measured in `Character` units to a `String.Index`,
    /// because `AttributedString` ranges need `String.Index`-derived ranges.
    func utf16Index(at characterOffset: Int) -> String.Index? {
        guard characterOffset >= 0 else { return nil }
        var index = startIndex
        var remaining = characterOffset
        while remaining > 0, index < endIndex {
            index = self.index(after: index)
            remaining -= 1
        }
        return remaining == 0 ? index : nil
    }
}
#endif
