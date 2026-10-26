import Foundation
import Testing
@testable import TimeTracker

struct DateRangeTests {
    let cal = TestCalendar.make()
    func d(_ y: Int, _ m: Int, _ day: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        TestCalendar.date(y, m, day, h, min, calendar: cal)
    }

    @Test func dayBoundaries() {
        let range = DateRange.day(of: d(2026, 10, 26, 15, 30), calendar: cal)
        #expect(range.start == d(2026, 10, 26))
        #expect(range.end == d(2026, 10, 27))
        #expect(range.duration == 86_400)
    }

    @Test func dstDaysHaveRealDuration() {
        let spring = DateRange.day(of: d(2026, 3, 29, 12), calendar: cal)
        let autumn = DateRange.day(of: d(2026, 10, 25, 12), calendar: cal)
        #expect(spring.duration == 23 * 3600)
        #expect(autumn.duration == 25 * 3600)
    }

    @Test func monthBoundaries() {
        let range = DateRange.month(of: d(2026, 2, 14), calendar: cal)
        #expect(range.start == d(2026, 2, 1))
        #expect(range.end == d(2026, 3, 1))
    }

    @Test func shifting() {
        let day = DateRange.day(of: d(2026, 10, 31), calendar: cal)
        #expect(day.shiftedDays(1, calendar: cal).start == d(2026, 11, 1))
        #expect(day.shiftedDays(-1, calendar: cal).start == d(2026, 10, 30))
        let month = DateRange.month(of: d(2026, 1, 15), calendar: cal)
        #expect(month.shiftedMonths(-1, calendar: cal).start == d(2025, 12, 1))
        #expect(month.shiftedMonths(1, calendar: cal).start == d(2026, 2, 1))
    }

    @Test func containsIsHalfOpen() {
        let range = DateRange.day(of: d(2026, 10, 26), calendar: cal)
        #expect(range.contains(range.start))
        #expect(!range.contains(range.end))
    }

    @Test func intersection() {
        let a = DateRange(start: d(2026, 1, 1, 10), end: d(2026, 1, 1, 12))
        let b = DateRange(start: d(2026, 1, 1, 11), end: d(2026, 1, 1, 13))
        let c = DateRange(start: d(2026, 1, 1, 12), end: d(2026, 1, 1, 13))
        #expect(a.intersection(with: b) == DateRange(start: d(2026, 1, 1, 11), end: d(2026, 1, 1, 12)))
        #expect(a.intersection(with: c) == nil)
        #expect(!a.overlaps(c))
    }
}
