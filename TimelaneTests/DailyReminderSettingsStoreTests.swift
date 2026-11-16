import Foundation
import Testing
@testable import Timelane

@MainActor
struct DailyReminderSettingsStoreTests {
    @Test func userDefaultsRoundTrip() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = UserDefaultsDailyReminderSettingsStore(defaults: defaults)
        #expect(store.settings == DailyReminderSettings())

        var settings = DailyReminderSettings()
        settings.isEnabled = true
        settings.setDay(1, isOn: true)
        settings.setTime(hour: 8, minute: 5, for: 1)
        store.settings = settings
        #expect(UserDefaultsDailyReminderSettingsStore(defaults: defaults).settings == settings)
    }

    @Test func unreadableDataFallsBackToDefaults() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(Data("not json".utf8), forKey: UserDefaultsDailyReminderSettingsStore.key)
        #expect(UserDefaultsDailyReminderSettingsStore(defaults: defaults).settings == DailyReminderSettings())
    }
}
