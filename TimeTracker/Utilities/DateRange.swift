import Foundation

/// A half-open time interval `[start, end)`. All day/month boundary math goes through here.
struct DateRange: Hashable, Sendable {
    let start: Date
    let end: Date

    var duration: TimeInterval { end.timeIntervalSince(start) }

    static func day(of date: Date, calendar: Calendar = .current) -> DateRange {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return DateRange(start: start, end: end)
    }

    static func month(of date: Date, calendar: Calendar = .current) -> DateRange {
        let start = calendar.startOfMonth(for: date)
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start.addingTimeInterval(30 * 86_400)
        return DateRange(start: start, end: end)
    }

    func contains(_ date: Date) -> Bool { date >= start && date < end }

    func overlaps(_ other: DateRange) -> Bool { start < other.end && other.start < end }

    func intersection(with other: DateRange) -> DateRange? {
        let lower = max(start, other.start)
        let upper = min(end, other.end)
        return lower < upper ? DateRange(start: lower, end: upper) : nil
    }

    /// The day range moved by `days` days (this range must be a day).
    func shiftedDays(_ days: Int, calendar: Calendar = .current) -> DateRange {
        let moved = calendar.date(byAdding: .day, value: days, to: start) ?? start
        return .day(of: moved, calendar: calendar)
    }

    /// The month range moved by `months` months (this range must be a month).
    func shiftedMonths(_ months: Int, calendar: Calendar = .current) -> DateRange {
        let moved = calendar.date(byAdding: .month, value: months, to: start) ?? start
        return .month(of: moved, calendar: calendar)
    }
}
