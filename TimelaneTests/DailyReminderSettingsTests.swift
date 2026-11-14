import Foundation
import Testing
@testable import Timelane

struct DailyReminderSettingsTests {
    @Test func offByDefaultWithWeekdaysAtFivePM() {
        let settings = DailyReminderSettings()
        #expect(!settings.isEnabled)
        #expect(settings.days.map(\.weekday) == Array(1...7))
        #expect(settings.days.filter(\.isOn).map(\.weekday) == [2, 3, 4, 5, 6])
        #expect(settings.days.allSatisfy { $0.hour == 17 && $0.minute == 0 })
    }

    @Test func setDayAndTimeOnlyChangeThatDay() {
        var settings = DailyReminderSettings()
        settings.setDay(7, isOn: true)
        settings.setDay(2, isOn: false)
        settings.setTime(hour: 16, minute: 30, for: 6)
        #expect(settings.day(7).isOn)
        #expect(!settings.day(2).isOn)
        #expect(settings.day(6).hour == 16 && settings.day(6).minute == 30)
        #expect(settings.day(5).hour == 17 && settings.day(5).minute == 0)
    }

    @Test func timesAreClamped() {
        var settings = DailyReminderSettings()
        settings.setTime(hour: 25, minute: -3, for: 3)
        #expect(settings.day(3).hour == 23)
        #expect(settings.day(3).minute == 0)
    }

    @Test func unknownWeekdayIsIgnored() {
        var settings = DailyReminderSettings()
        settings.setDay(9, isOn: true)
        #expect(settings == DailyReminderSettings())
    }

    @Test func normalizedRepairsStoredDays() throws {
        let json = """
        {"isEnabled":true,"days":[
            {"weekday":3,"isOn":true,"hour":30,"minute":75},
            {"weekday":3,"isOn":false,"hour":8,"minute":0},
            {"weekday":12,"isOn":true,"hour":8,"minute":0}
        ]}
        """
        let stored = try JSONDecoder().decode(DailyReminderSettings.self, from: Data(json.utf8))
        let settings = stored.normalized()
        #expect(settings.isEnabled)
        #expect(settings.days.map(\.weekday) == Array(1...7))
        #expect(settings.day(3) == ReminderDay(weekday: 3, isOn: true, hour: 23, minute: 59))
        #expect(settings.day(2) == DailyReminderSettings.defaultDays[1])
    }

    @Test func missingKeysKeepTheDefaults() throws {
        let settings = try JSONDecoder().decode(DailyReminderSettings.self, from: Data(#"{"isEnabled":true}"#.utf8))
        #expect(settings.isEnabled)
        #expect(settings.days == DailyReminderSettings.defaultDays)
    }

    @Test func codableRoundTrip() throws {
        var settings = DailyReminderSettings()
        settings.isEnabled = true
        settings.setTime(hour: 9, minute: 15, for: 1)
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(DailyReminderSettings.self, from: data) == settings)
    }
}
