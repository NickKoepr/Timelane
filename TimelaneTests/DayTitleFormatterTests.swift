import Foundation
import Testing
@testable import Timelane

struct DayTitleFormatterTests {
    private var formatter: DayTitleFormatter {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return DayTitleFormatter(calendar: calendar, locale: Locale(identifier: "en_US"))
    }
    // 26 October 2026 is a Monday.
    private let date = Date(timeIntervalSince1970: 1_792_972_800 + 12 * 3600)

    @Test func fullTitleSpellsEverythingOut() {
        let title = formatter.full(date)
        #expect(title.contains("Monday") && title.contains("October") && title.contains("26") && title.contains("2026"))
    }

    @Test func shortTitleIsAbbreviatedWithoutYear() {
        let title = formatter.short(date)
        #expect(title.contains("Mon") && title.contains("Oct") && title.contains("26"))
        #expect(!title.contains("2026") && !title.contains("Monday") && !title.contains("October"))
    }
}
