import Foundation
import Testing
@testable import Timelane

struct DailyReminderScheduleTests {
    let calendar = TestCalendar.make()

    func enabled(_ change: (inout DailyReminderSettings) -> Void = { _ in }) -> DailyReminderSettings {
        var settings = DailyReminderSettings()
        settings.isEnabled = true
        change(&settings)
        return settings
    }

    @Test func disabledHasNoRequests() {
        #expect(DailyReminderSchedule.requests(for: DailyReminderSettings()).isEmpty)
    }

    @Test func oneRequestPerDayThatIsOn() {
        let settings = enabled { $0.setTime(hour: 16, minute: 45, for: 6) }
        let requests = DailyReminderSchedule.requests(for: settings)
        #expect(requests.map(\.weekday) == [2, 3, 4, 5, 6])
        #expect(requests.last == ReminderRequest(identifier: "dailyReminder.weekday6", weekday: 6, hour: 16, minute: 45))
        #expect(requests.first?.hour == 17)
    }

    @Test func identifiersCoverEveryWeekday() {
        let identifiers = DailyReminderSchedule.allIdentifiers
        #expect(identifiers.count == 7)
        #expect(Set(identifiers).count == 7)
        #expect(identifiers.allSatisfy { $0.hasPrefix(DailyReminderSchedule.identifierPrefix) })
        let used = DailyReminderSchedule.requests(for: enabled { s in (1...7).forEach { s.setDay($0, isOn: true) } })
        #expect(Set(used.map(\.identifier)) == Set(identifiers))
    }

    @Test func nextDateLaterToday() {
        // Tuesday 3 November 2026, 14:30.
        let now = TestCalendar.date(2026, 11, 3, 14, 30)
        let next = DailyReminderSchedule.nextDate(for: enabled(), after: now, calendar: calendar)
        #expect(next == TestCalendar.date(2026, 11, 3, 17, 0))
    }

    @Test func nextDateSkipsToTheNextDayThatIsOn() {
        // Friday 6 November 2026, 18:00: the weekend is off, so Monday.
        let now = TestCalendar.date(2026, 11, 6, 18, 0)
        let next = DailyReminderSchedule.nextDate(for: enabled(), after: now, calendar: calendar)
        #expect(next == TestCalendar.date(2026, 11, 9, 17, 0))
    }

    @Test func nextDateUsesEachDaysOwnTime() {
        let now = TestCalendar.date(2026, 11, 3, 14, 30)
        let settings = enabled { settings in
            settings.setTime(hour: 9, minute: 0, for: 3)
            settings.setTime(hour: 8, minute: 0, for: 4)
        }
        let next = DailyReminderSchedule.nextDate(for: settings, after: now, calendar: calendar)
        #expect(next == TestCalendar.date(2026, 11, 4, 8, 0))
    }

    @Test func nextDateWrapsToNextWeek() {
        let now = TestCalendar.date(2026, 11, 3, 18, 0)
        let settings = enabled { s in (1...7).filter { $0 != 3 }.forEach { s.setDay($0, isOn: false) } }
        let next = DailyReminderSchedule.nextDate(for: settings, after: now, calendar: calendar)
        #expect(next == TestCalendar.date(2026, 11, 10, 17, 0))
    }

    @Test func noNextDateWithoutDays() {
        let settings = enabled { s in (1...7).forEach { s.setDay($0, isOn: false) } }
        #expect(DailyReminderSchedule.nextDate(for: settings, after: .now, calendar: calendar) == nil)
        #expect(DailyReminderSchedule.nextDate(for: DailyReminderSettings(), after: .now, calendar: calendar) == nil)
    }
}
