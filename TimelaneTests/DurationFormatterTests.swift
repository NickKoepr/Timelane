import Foundation
import Testing
@testable import Timelane

struct DurationFormatterTests {
    @Test func hoursMinutes() {
        #expect(DurationFormatter.hoursMinutes(0) == "0:00")
        #expect(DurationFormatter.hoursMinutes(45 * 60) == "0:45")
        #expect(DurationFormatter.hoursMinutes(42 * 3600 + 15 * 60) == "42:15")
        #expect(DurationFormatter.hoursMinutes(-5) == "0:00")
        #expect(DurationFormatter.hoursMinutes(59.6 * 60) == "1:00")
    }

    @Test func minutes() {
        #expect(DurationFormatter.minutes(90 * 60) == 90)
        #expect(DurationFormatter.minutes(29) == 0)
        #expect(DurationFormatter.minutes(30) == 1)
        #expect(DurationFormatter.minutes(-5) == 0)
    }

    @Test func short() {
        #expect(DurationFormatter.short(45 * 60) == "45m")
        #expect(DurationFormatter.short(3 * 3600) == "3h")
        #expect(DurationFormatter.short(3 * 3600 + 45 * 60) == "3h 45m")
    }
}

struct DurationClockTests {
    @Test func formatsHoursMinutesSeconds() {
        #expect(DurationFormatter.clock(0) == "0:00:00")
        #expect(DurationFormatter.clock(754) == "0:12:34")
        #expect(DurationFormatter.clock(3661.9) == "1:01:01")
        #expect(DurationFormatter.clock(-5) == "0:00:00")
    }
}
