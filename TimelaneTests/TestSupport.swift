import Foundation
@testable import Timelane

/// Fixed calendar so tests don't depend on the machine's time zone.
enum TestCalendar {
    static func make(_ zone: String = "Europe/Amsterdam") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0,
                     calendar: Calendar = make()) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }
}
