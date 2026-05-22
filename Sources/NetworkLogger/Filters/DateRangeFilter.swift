import Foundation

/// Matches events whose `startDate` falls within the given closed range.
public struct DateRangeFilter: EventFilter {
    public let range: ClosedRange<Date>

    public init(_ range: ClosedRange<Date>) {
        self.range = range
    }

    public func includes(_ event: NetworkEvent) -> Bool {
        range.contains(event.startDate)
    }
}

public extension DateRangeFilter {
    /// Common presets for the date-range picker UI.
    enum Preset: String, CaseIterable, Sendable {
        case last5Minutes
        case lastHour
        case today
        case yesterday
        case last7Days

        public var displayLabel: String {
            switch self {
            case .last5Minutes: return "Last 5 minutes"
            case .lastHour: return "Last hour"
            case .today: return "Today"
            case .yesterday: return "Yesterday"
            case .last7Days: return "Last 7 days"
            }
        }

        public func range(now: Date = Date(), calendar: Calendar = .current) -> ClosedRange<Date> {
            switch self {
            case .last5Minutes:
                return now.addingTimeInterval(-300)...now
            case .lastHour:
                return now.addingTimeInterval(-3600)...now
            case .today:
                let start = calendar.startOfDay(for: now)
                return start...now
            case .yesterday:
                let startOfToday = calendar.startOfDay(for: now)
                let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
                let endOfYesterday = startOfToday.addingTimeInterval(-1)
                return startOfYesterday...endOfYesterday
            case .last7Days:
                return now.addingTimeInterval(-7 * 86_400)...now
            }
        }
    }
}
