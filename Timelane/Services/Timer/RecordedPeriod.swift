import Foundation

/// The result of a finished recording, ready for the new-entry form. Pure value type.
struct RecordedPeriod: Equatable {
    /// Start rounded down and end rounded up to whole minutes, on the start day.
    let range: DateRange
    /// The recording ran past midnight; `range` ends at the end of the start day.
    let continuedPastMidnight: Bool

    static let minute: TimeInterval = 60

    /// nil when the period is shorter than a minute even after rounding (or the end is not after the start).
    init?(start: Date, end: Date, calendar: Calendar = .current) {
        guard end > start else { return nil }
        let day = DateRange.day(of: start, calendar: calendar)
        let roundedStart = Self.floorToMinute(start)
        var roundedEnd = Self.ceilToMinute(end)
        let crossed = roundedEnd > day.end
        if crossed { roundedEnd = max(day.end.addingTimeInterval(-Self.minute), roundedStart.addingTimeInterval(Self.minute)) }
        guard roundedEnd.timeIntervalSince(roundedStart) >= Self.minute else { return nil }
        range = DateRange(start: roundedStart, end: roundedEnd)
        continuedPastMidnight = crossed
    }

    static let midnightNotice = "Recording continued past midnight — the rest was not included."

    private static func floorToMinute(_ date: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate / minute).rounded(.down) * minute)
    }

    private static func ceilToMinute(_ date: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate / minute).rounded(.up) * minute)
    }
}
