import Testing
@testable import TimeTracker

struct DurationFormatterTests {
    @Test func hoursMinutes() {
        #expect(DurationFormatter.hoursMinutes(0) == "0:00")
        #expect(DurationFormatter.hoursMinutes(45 * 60) == "0:45")
        #expect(DurationFormatter.hoursMinutes(42 * 3600 + 15 * 60) == "42:15")
        #expect(DurationFormatter.hoursMinutes(-5) == "0:00")
        #expect(DurationFormatter.hoursMinutes(59.6 * 60) == "1:00")
    }

    @Test func short() {
        #expect(DurationFormatter.short(45 * 60) == "45m")
        #expect(DurationFormatter.short(3 * 3600) == "3h")
        #expect(DurationFormatter.short(3 * 3600 + 45 * 60) == "3h 45m")
    }
}
