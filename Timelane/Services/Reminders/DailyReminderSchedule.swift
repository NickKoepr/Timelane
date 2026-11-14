import Foundation

/// Turns `DailyReminderSettings` into notification requests: one repeating request per day that is on.
enum DailyReminderSchedule {
    static let identifierPrefix = "dailyReminder."
    static let title = "Time to log your hours"
    static let body = "Register what you worked on today in Timelane."

    /// Every identifier the reminder can use, so a day that was turned off loses its request too.
    static let allIdentifiers: [String] = (1...7).map { DailyReminderSchedule.identifier(for: $0) }

    static func identifier(for weekday: Int) -> String {
        "\(identifierPrefix)weekday\(weekday)"
    }

    /// Nothing while the reminder is off.
    static func requests(for settings: DailyReminderSettings) -> [ReminderRequest] {
        guard settings.isEnabled else { return [] }
        return settings.days.filter(\.isOn).map { day in
            ReminderRequest(identifier: identifier(for: day.weekday), weekday: day.weekday,
                            hour: day.hour, minute: day.minute)
        }
    }

    /// When the next reminder fires after `date`, or nil when none would.
    static func nextDate(for settings: DailyReminderSettings, after date: Date, calendar: Calendar) -> Date? {
        requests(for: settings)
            .compactMap { request in
                calendar.nextDate(after: date,
                                  matching: DateComponents(hour: request.hour, minute: request.minute, second: 0,
                                                           weekday: request.weekday),
                                  matchingPolicy: .nextTime)
            }
            .min()
    }
}
