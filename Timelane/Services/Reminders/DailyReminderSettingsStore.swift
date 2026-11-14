import Foundation

/// Where the reminder settings survive app restarts.
@MainActor
protocol DailyReminderSettingsStore: AnyObject {
    var settings: DailyReminderSettings { get set }
}

@MainActor
final class InMemoryDailyReminderSettingsStore: DailyReminderSettingsStore {
    var settings: DailyReminderSettings
    init(settings: DailyReminderSettings = DailyReminderSettings()) { self.settings = settings }
}

/// JSON in `UserDefaults`; unreadable data falls back to the defaults (reminder off).
@MainActor
final class UserDefaultsDailyReminderSettingsStore: DailyReminderSettingsStore {
    static let key = "dailyReminder.settings"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var settings: DailyReminderSettings {
        get {
            guard let data = defaults.data(forKey: Self.key),
                  let stored = try? JSONDecoder().decode(DailyReminderSettings.self, from: data) else {
                return DailyReminderSettings()
            }
            return stored.normalized()
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: Self.key)
        }
    }
}
