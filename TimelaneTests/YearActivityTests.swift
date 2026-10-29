import Foundation
import Testing
@testable import Timelane

struct YearActivityTests {
    let cal = TestCalendar.make()
    func d(_ y: Int, _ m: Int, _ day: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        TestCalendar.date(y, m, day, h, min, calendar: cal)
    }
    var year: DateRange { .year(of: d(2026, 6, 1), calendar: cal) }
    func entry(_ project: Int64, _ start: Date, _ end: Date) -> TimeEntry {
        TimeEntry(projectId: project, start: start, end: end)
    }

    @Test func splitsAtMidnight() {
        let activity = YearActivity(entries: [entry(1, d(2026, 3, 3, 23), d(2026, 3, 4, 1))], year: year, calendar: cal)
        #expect(activity.seconds(on: d(2026, 3, 3), projectId: nil) == 3600)
        #expect(activity.seconds(on: d(2026, 3, 4), projectId: nil) == 3600)
        #expect(activity.secondsByDay.count == 2)
    }

    @Test func clipsToYear() {
        let activity = YearActivity(entries: [
            entry(1, d(2025, 12, 31, 23), d(2026, 1, 1, 2)),
            entry(1, d(2026, 12, 31, 22), d(2027, 1, 1, 3)),
        ], year: year, calendar: cal)
        #expect(activity.seconds(on: d(2026, 1, 1), projectId: nil) == 2 * 3600)
        #expect(activity.seconds(on: d(2026, 12, 31), projectId: nil) == 2 * 3600)
        #expect(activity.secondsByDay.count == 2)
    }

    @Test func dstDaysBucketCorrectly() {
        // Whole-day entries on the 23 h and 25 h days land on one day each.
        let spring = DateRange.day(of: d(2026, 3, 29), calendar: cal)
        let autumn = DateRange.day(of: d(2026, 10, 25), calendar: cal)
        let activity = YearActivity(entries: [
            entry(1, spring.start, spring.end), entry(1, autumn.start, autumn.end),
        ], year: year, calendar: cal)
        #expect(activity.secondsByDay.count == 2)
        #expect(activity.seconds(on: spring.start, projectId: nil) == 23 * 3600)
        #expect(activity.seconds(on: autumn.start, projectId: nil) == 25 * 3600)
    }

    @Test func projectFilter() {
        let activity = YearActivity(entries: [
            entry(1, d(2026, 2, 2, 9), d(2026, 2, 2, 10)),
            entry(2, d(2026, 2, 2, 11), d(2026, 2, 2, 13)),
        ], year: year, calendar: cal)
        let day = d(2026, 2, 2)
        #expect(activity.seconds(on: day, projectId: nil) == 3 * 3600)
        #expect(activity.seconds(on: day, projectId: 2) == 2 * 3600)
        #expect(activity.seconds(on: day, projectId: 3) == 0)
        #expect(activity.dailyTotals(projectId: 1) == [day: 3600])
        #expect(activity.dailyTotals(projectId: 3).isEmpty)
        #expect(activity.projectTotals() == [1: 3600, 2: 7200])
    }

    @Test func monthlyTotalsHaveTwelveItemsAndSum() {
        let activity = YearActivity(entries: [
            entry(1, d(2026, 1, 31, 23), d(2026, 2, 1, 1)),
            entry(2, d(2026, 12, 5, 9), d(2026, 12, 5, 12)),
        ], year: year, calendar: cal)
        let months = activity.monthlyTotals(projectId: nil, calendar: cal)
        #expect(months.count == 12)
        #expect(months[0] == [1: 3600])
        #expect(months[1] == [1: 3600])
        #expect(months[11] == [2: 3 * 3600])
        #expect(months.flatMap(\.values).reduce(0, +) == activity.projectTotals().values.reduce(0, +))
        #expect(activity.monthlyTotals(projectId: 2, calendar: cal)[0].isEmpty)
    }
}
