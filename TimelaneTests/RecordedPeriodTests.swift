import Foundation
import Testing
@testable import Timelane

struct RecordedPeriodTests {
    let cal = TestCalendar.make()
    func at(_ h: Int, _ m: Int, _ s: Double = 0, day: Int = 3) -> Date {
        TestCalendar.date(2026, 11, day, h, m).addingTimeInterval(s)
    }

    @Test func roundsStartDownAndEndUp() throws {
        let period = try #require(RecordedPeriod(start: at(9, 0, 40), end: at(9, 12, 5), calendar: cal))
        #expect(period.range.start == at(9, 0))
        #expect(period.range.end == at(9, 13))
        #expect(!period.continuedPastMidnight)
    }

    @Test func exactMinutesStayAndZeroLengthIsRejected() throws {
        let period = try #require(RecordedPeriod(start: at(9, 0), end: at(9, 5), calendar: cal))
        #expect(period.range == DateRange(start: at(9, 0), end: at(9, 5)))
        #expect(RecordedPeriod(start: at(9, 0), end: at(9, 0), calendar: cal) == nil)
    }

    @Test func shortRecordingBecomesOneMinuteAtLeast() throws {
        let period = try #require(RecordedPeriod(start: at(9, 0, 10), end: at(9, 0, 20), calendar: cal))
        #expect(period.range.duration == 60)
        let across = try #require(RecordedPeriod(start: at(9, 0, 50), end: at(9, 1, 10), calendar: cal))
        #expect(across.range == DateRange(start: at(9, 0), end: at(9, 2)))
    }

    @Test func crossingMidnightIsClampedToTheStartDay() throws {
        let period = try #require(RecordedPeriod(start: at(23, 30), end: at(0, 20, day: 4), calendar: cal))
        #expect(period.continuedPastMidnight)
        #expect(period.range == DateRange(start: at(23, 30), end: at(23, 59)))
    }

    @Test func startingInTheLastMinuteStillGivesOneMinute() throws {
        let period = try #require(RecordedPeriod(start: at(23, 59, 10), end: at(0, 10, day: 4), calendar: cal))
        #expect(period.continuedPastMidnight)
        #expect(period.range == DateRange(start: at(23, 59), end: at(0, 0, day: 4)))
    }

    @Test func dstDayStaysOnTheStartDay() throws {
        // 2026-10-25 has 25 hours in Europe/Amsterdam.
        let start = TestCalendar.date(2026, 10, 25, 23, 0)
        let period = try #require(RecordedPeriod(start: start, end: start.addingTimeInterval(1800), calendar: cal))
        #expect(period.range.duration == 1800)
        #expect(!period.continuedPastMidnight)
    }
}
