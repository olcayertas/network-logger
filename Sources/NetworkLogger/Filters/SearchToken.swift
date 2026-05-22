import Foundation

/// A structured filter parsed from the search bar.
///
/// Inspired by Pulse's `ConsoleSearchToken`. Users type forms like `host:api.example.com`,
/// `method:POST`, `path:/users`, `statusCode:2XX` and the parser hoists them out of the
/// free-text query.
public enum SearchToken: Sendable, Hashable {
    case host(String)
    case method(String)        // canonicalised to uppercase
    case path(String)
    case statusCode(StatusCodeRange)

    public var key: String {
        switch self {
        case .host: return "host"
        case .method: return "method"
        case .path: return "path"
        case .statusCode: return "statusCode"
        }
    }

    public var systemImage: String {
        switch self {
        case .host: return "server.rack"
        case .method: return "arrow.up.arrow.down"
        case .path: return "slash.circle"
        case .statusCode: return "number"
        }
    }

    public var displayLabel: String {
        switch self {
        case let .host(value): return "host:\(value)"
        case let .method(value): return "method:\(value)"
        case let .path(value): return "path:\(value)"
        case let .statusCode(range): return "status:\(range.displayLabel)"
        }
    }

    /// The original search-bar substring this token was parsed from.
    /// Used by the UI to surgically remove the token from the user's input.
    public var rawSpelling: String {
        switch self {
        case let .host(value): return "host:\(value)"
        case let .method(value): return "method:\(value)"
        case let .path(value): return "path:\(value)"
        case let .statusCode(range):
            if range.lower == range.upper {
                return "statusCode:\(range.lower)"
            }
            if range.lower / 100 == range.upper / 100, range.lower % 100 == 0, range.upper % 100 == 99 {
                return "statusCode:\(range.lower / 100)XX"
            }
            return "statusCode:\(range.lower)...\(range.upper)"
        }
    }

    /// The `EventFilter` this token evaluates to.
    public var filter: any EventFilter {
        switch self {
        case let .host(value): return HostFilter(allowing: [value])
        case let .method(value): return MethodFilter(value)
        case let .path(value): return URLPathFilter(value)
        case let .statusCode(range): return StatusCodeRangeFilter(range.closedRange)
        }
    }
}
