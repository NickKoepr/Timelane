import Foundation

enum MonthExportFileName {
    /// "Timelane 2026-10.json", from the month start in `calendar`.
    static func make(for month: DateRange, fileExtension: String, calendar: Calendar) -> String {
        "Timelane \(monthKey(month, calendar: calendar)).\(fileExtension)"
    }

    /// "2026-10"
    static func monthKey(_ month: DateRange, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month], from: month.start)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }
}
