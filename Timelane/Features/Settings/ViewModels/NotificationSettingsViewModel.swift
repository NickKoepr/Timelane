import Foundation

/// Settings ▸ Notifications: the reminder to log hours, with a checkbox and a time per weekday.
@MainActor @Observable
final class NotificationSettingsViewModel {
    var errorMessage: String?
    /// Turning the reminder on was refused because Timelane may not send notifications.
    private(set) var wasRefused = false

    private let service: DailyReminderService
    private let calendar: Calendar
    private let now: () -> Date

    init(service: DailyReminderService, calendar: Calendar = .current, now: @escaping () -> Date = { .now }) {
        self.service = service
        self.calendar = calendar
        self.now = now
    }

    var isEnabled: Bool { service.settings.isEnabled }

    /// The seven weekdays in the order of the user's calendar (Monday first in the Netherlands).
    var weekdays: [Int] {
        (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
    }

    func name(of weekday: Int) -> String {
        calendar.weekdaySymbols[weekday - 1]
    }

    func isOn(_ weekday: Int) -> Bool { service.settings.day(weekday).isOn }

    func setOn(_ isOn: Bool, for weekday: Int) { service.setDay(weekday, isOn: isOn) }

    /// The day's reminder time as a date today: what the time picker edits.
    func time(for weekday: Int) -> Date {
        let day = service.settings.day(weekday)
        return calendar.date(bySettingHour: day.hour, minute: day.minute, second: 0, of: now()) ?? now()
    }

    func setTime(_ date: Date, for weekday: Int) {
        let time = calendar.dateComponents([.hour, .minute], from: date)
        service.setTime(hour: time.hour ?? DailyReminderSettings.defaultHour, minute: time.minute ?? 0, for: weekday)
    }

    /// Why no reminders can be shown, with a way to System Settings in the view; nil when nothing blocks them.
    var permissionMessage: String? {
        if isEnabled, service.authorization == .denied {
            return "Notifications for Timelane are turned off in System Settings, so no reminders are shown."
        }
        if wasRefused {
            return "Timelane isn't allowed to send notifications. Allow them in System Settings, then turn the reminder on again."
        }
        return nil
    }

    /// "Next reminder: tomorrow at 17:00", or a hint while no day is chosen.
    var scheduleSummary: String {
        guard let next = DailyReminderSchedule.nextDate(for: service.settings, after: now(), calendar: calendar) else {
            return "Choose at least one day."
        }
        let style = Date.FormatStyle(date: .omitted, time: .shortened, locale: calendar.locale ?? .autoupdatingCurrent,
                                     calendar: calendar, timeZone: calendar.timeZone)
        return "Next reminder: \(dayDescription(of: next)) at \(next.formatted(style))"
    }

    /// System Settings ▸ Notifications, at Timelane's entry.
    var systemSettingsURL: URL? {
        let bundleId = Bundle.main.bundleIdentifier ?? "nl.nickkoepr.timelane"
        return URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(bundleId)")
    }

    func setEnabled(_ enabled: Bool) async {
        errorMessage = nil
        wasRefused = false
        do {
            let isAllowed = try await service.setEnabled(enabled)
            wasRefused = !isAllowed
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        await service.refresh()
    }

    private func dayDescription(of date: Date) -> String {
        let today = now()
        if calendar.isDate(date, inSameDayAs: today) { return "today" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today), calendar.isDate(date, inSameDayAs: tomorrow) {
            return "tomorrow"
        }
        return name(of: calendar.component(.weekday, from: date))
    }
}
