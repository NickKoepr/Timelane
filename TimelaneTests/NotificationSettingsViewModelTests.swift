import Foundation
import Testing
@testable import Timelane

@MainActor
struct NotificationSettingsViewModelTests {
    struct TestError: LocalizedError {
        var errorDescription: String? { "Notifications are not available." }
    }

    struct Fixture {
        let model: NotificationSettingsViewModel
        let service: DailyReminderService
        let scheduler: InMemoryNotificationScheduler
    }

    /// Monday-first English calendar in Amsterdam, so names, order and times don't depend on the machine.
    static func calendar() -> Calendar {
        var calendar = TestCalendar.make()
        calendar.locale = Locale(identifier: "en_GB")
        calendar.firstWeekday = 2
        return calendar
    }

    func make(now: Date = TestCalendar.date(2026, 11, 3, 14, 30), grantsPermission: Bool = true) -> Fixture {
        let scheduler = InMemoryNotificationScheduler(grantsPermission: grantsPermission)
        let service = DailyReminderService(store: InMemoryDailyReminderSettingsStore(), scheduler: scheduler)
        let model = NotificationSettingsViewModel(service: service, calendar: Self.calendar(), now: { now })
        return Fixture(model: model, service: service, scheduler: scheduler)
    }

    @Test func weekdaysFollowTheFirstWeekday() {
        let f = make()
        #expect(f.model.weekdays == [2, 3, 4, 5, 6, 7, 1])
        #expect(f.model.name(of: 2) == "Monday")
        #expect(f.model.name(of: 1) == "Sunday")

        var sundayFirst = Self.calendar()
        sundayFirst.firstWeekday = 1
        let model = NotificationSettingsViewModel(service: f.service, calendar: sundayFirst)
        #expect(model.weekdays == [1, 2, 3, 4, 5, 6, 7])
    }

    @Test func enablingTurnsTheDaysOn() async {
        let f = make()
        #expect(!f.model.isEnabled)
        await f.model.setEnabled(true)
        #expect(f.model.isEnabled)
        #expect(f.model.isOn(2))
        #expect(!f.model.isOn(1))
        #expect(f.model.permissionMessage == nil)
        #expect(f.scheduler.pendingRequests.count == 5)
    }

    @Test func timeRoundTripsThroughThePicker() async {
        let f = make()
        await f.model.setEnabled(true)
        let calendar = Self.calendar()
        #expect(f.model.time(for: 2) == TestCalendar.date(2026, 11, 3, 17, 0))
        f.model.setTime(TestCalendar.date(2026, 1, 1, 8, 45), for: 2)
        let time = calendar.dateComponents([.hour, .minute], from: f.model.time(for: 2))
        #expect(time.hour == 8 && time.minute == 45)
        #expect(f.scheduler.pendingRequests.first?.hour == 8)
        #expect(f.scheduler.pendingRequests.first?.minute == 45)
    }

    @Test func togglingADayUpdatesTheSchedule() async {
        let f = make()
        await f.model.setEnabled(true)
        f.model.setOn(false, for: 3)
        f.model.setOn(true, for: 1)
        #expect(!f.model.isOn(3))
        #expect(f.scheduler.pendingRequests.map(\.weekday) == [1, 2, 4, 5, 6])
    }

    @Test func refusedPermissionExplainsWhy() async {
        let f = make(grantsPermission: false)
        await f.model.setEnabled(true)
        #expect(!f.model.isEnabled)
        #expect(f.model.permissionMessage?.contains("isn't allowed") == true)
        // Trying again (or turning it off) starts from a clean message.
        f.scheduler.status = .authorized
        await f.model.setEnabled(true)
        #expect(f.model.permissionMessage == nil)
    }

    @Test func blockedLaterShowsAWarningWhileOn() async {
        let f = make()
        await f.model.setEnabled(true)
        f.scheduler.status = .denied
        await f.model.refresh()
        #expect(f.model.isEnabled)
        #expect(f.model.permissionMessage?.contains("turned off in System Settings") == true)
        await f.model.setEnabled(false)
        #expect(f.model.permissionMessage == nil)
    }

    @Test func requestErrorIsShown() async {
        let f = make()
        f.scheduler.error = TestError()
        await f.model.setEnabled(true)
        #expect(f.model.errorMessage == "Notifications are not available.")
        #expect(!f.model.isEnabled)
    }

    @Test func summaryNamesTheNextReminder() async {
        // Tuesday 14:30: today at 17:00.
        let today = make()
        await today.model.setEnabled(true)
        #expect(today.model.scheduleSummary == "Next reminder: today at 17:00")

        // Tuesday 18:00: tomorrow.
        let tomorrow = make(now: TestCalendar.date(2026, 11, 3, 18, 0))
        await tomorrow.model.setEnabled(true)
        #expect(tomorrow.model.scheduleSummary == "Next reminder: tomorrow at 17:00")

        // Friday 18:00: the weekend is off, so Monday.
        let monday = make(now: TestCalendar.date(2026, 11, 6, 18, 0))
        await monday.model.setEnabled(true)
        #expect(monday.model.scheduleSummary == "Next reminder: Monday at 17:00")
    }

    @Test func summaryAsksForADayWhenNoneIsOn() async {
        let f = make()
        await f.model.setEnabled(true)
        for weekday in 1...7 { f.model.setOn(false, for: weekday) }
        #expect(f.model.scheduleSummary == "Choose at least one day.")
    }

    @Test func systemSettingsLinkPointsAtNotifications() {
        let url = make().model.systemSettingsURL
        #expect(url?.scheme == "x-apple.systempreferences")
        #expect(url?.absoluteString.contains("com.apple.Notifications-Settings.extension") == true)
    }
}
