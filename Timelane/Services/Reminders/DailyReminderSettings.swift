import Foundation

/// The "log your hours" reminder: off by default; when on, it fires on the days that are on, each at its own time.
struct DailyReminderSettings: Codable, Equatable, Sendable {
    static let defaultHour = 17
    static let defaultMinute = 0

    var isEnabled = false
    /// Always seven days, weekday 1 (Sunday) … 7 (Saturday).
    private(set) var days = DailyReminderSettings.defaultDays

    private enum CodingKeys: String, CodingKey {
        case isEnabled, days
    }

    /// Monday to Friday on, Saturday and Sunday off, all at 17:00.
    static var defaultDays: [ReminderDay] {
        (1...7).map { defaultDay($0, isOn: (2...6).contains($0)) }
    }

    func day(_ weekday: Int) -> ReminderDay {
        days.first { $0.weekday == weekday } ?? Self.defaultDay(weekday, isOn: false)
    }

    mutating func setDay(_ weekday: Int, isOn: Bool) {
        modifyDay(weekday) { $0.isOn = isOn }
    }

    mutating func setTime(hour: Int, minute: Int, for weekday: Int) {
        modifyDay(weekday) { day in
            day.hour = min(max(hour, 0), 23)
            day.minute = min(max(minute, 0), 59)
        }
    }

    /// Exactly one valid day per weekday, in weekday order, whatever was stored; missing days get the defaults.
    func normalized() -> DailyReminderSettings {
        var result = self
        result.days = Self.defaultDays.map { fallback in
            guard var day = days.first(where: { $0.weekday == fallback.weekday }) else { return fallback }
            day.hour = min(max(day.hour, 0), 23)
            day.minute = min(max(day.minute, 0), 59)
            return day
        }
        return result
    }

    private mutating func modifyDay(_ weekday: Int, _ change: (inout ReminderDay) -> Void) {
        guard let index = days.firstIndex(where: { $0.weekday == weekday }) else { return }
        change(&days[index])
    }

    private static func defaultDay(_ weekday: Int, isOn: Bool) -> ReminderDay {
        ReminderDay(weekday: weekday, isOn: isOn, hour: defaultHour, minute: defaultMinute)
    }
}

extension DailyReminderSettings {
    /// Missing keys keep their defaults, so settings saved by another app version still load.
    init(from decoder: any Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? isEnabled
        days = try container.decodeIfPresent([ReminderDay].self, forKey: .days) ?? days
    }
}
