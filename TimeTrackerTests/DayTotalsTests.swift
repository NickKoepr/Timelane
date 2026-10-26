import Foundation
import Testing
@testable import TimeTracker

struct DayTotalsTests {
    let cal = TestCalendar.make()
    func d(_ day: Int, _ h: Int, _ m: Int = 0) -> Date { TestCalendar.date(2026, 11, day, h, m, calendar: cal) }

    @Test func registeredClipsToDay() {
        let day = DateRange.day(of: d(3, 12), calendar: cal)
        let entries = [
            TimeEntry(projectId: 1, start: d(3, 9), end: d(3, 10)),
            TimeEntry(projectId: 1, start: d(3, 23), end: d(4, 2)),
        ]
        #expect(DayTotals.registered(entries: entries, in: day) == 7200)
    }

    @Test func trackedUsesNowForOpenSession() {
        let day = DateRange.day(of: d(3, 12), calendar: cal)
        let sessions = [
            AppSession(bundleIdentifier: "a", appName: "A", start: d(3, 9), end: d(3, 10)),
            AppSession(bundleIdentifier: "b", appName: "B", start: d(3, 11), end: nil),
        ]
        #expect(DayTotals.tracked(sessions: sessions, in: day, now: d(3, 11, 30)) == 3600 + 1800)
    }
}
