import Foundation
import Testing
@testable import NetworkLogger

@Suite("DateRangeFilter")
struct DateRangeFilterTests {
    @Test("includes events within the range")
    func includesWithinRange() {
        let now = Date()
        let filter = DateRangeFilter(now.addingTimeInterval(-60)...now)
        let inRange = makeEvent(at: now.addingTimeInterval(-30))
        #expect(filter.includes(inRange))
    }

    @Test("excludes events outside the range")
    func excludesOutsideRange() {
        let now = Date()
        let filter = DateRangeFilter(now.addingTimeInterval(-60)...now)
        let before = makeEvent(at: now.addingTimeInterval(-120))
        let after = makeEvent(at: now.addingTimeInterval(60))
        #expect(!filter.includes(before))
        #expect(!filter.includes(after))
    }

    @Test("range bounds are inclusive")
    func rangeBoundsInclusive() {
        let lower = Date(timeIntervalSince1970: 1_000_000)
        let upper = Date(timeIntervalSince1970: 2_000_000)
        let filter = DateRangeFilter(lower...upper)
        #expect(filter.includes(makeEvent(at: lower)))
        #expect(filter.includes(makeEvent(at: upper)))
    }

    @Test("preset last5Minutes covers the right window")
    func presetLast5Minutes() {
        let now = Date()
        let range = DateRangeFilter.Preset.last5Minutes.range(now: now)
        #expect(range.upperBound == now)
        #expect(range.lowerBound == now.addingTimeInterval(-300))
    }

    @Test("preset today starts at midnight")
    func presetTodayStartsAtMidnight() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let range = DateRangeFilter.Preset.today.range(now: now, calendar: calendar)
        #expect(range.lowerBound == calendar.startOfDay(for: now))
    }

    private func makeEvent(at date: Date) -> NetworkEvent {
        NetworkEvent(
            startDate: date,
            request: NetworkRequestSnapshot(url: URL(string: "https://x")!, httpMethod: "GET")
        )
    }
}
