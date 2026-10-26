import Foundation

/// Day titles for the navigation bars. Pure, so locale/calendar can be fixed in tests.
struct DayTitleFormatter {
    var calendar: Calendar = .current
    var locale: Locale = .current

    /// "Monday 26 October 2026" (order depends on the locale).
    func full(_ date: Date) -> String {
        date.formatted(style().weekday(.wide).day().month(.wide).year())
    }

    /// "Mon 26 Oct" — used when the bar is narrow.
    func short(_ date: Date) -> String {
        date.formatted(style().weekday(.abbreviated).day().month(.abbreviated))
    }

    private func style() -> Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
    }
}
