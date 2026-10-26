import Foundation

/// Pure helpers for the registered and tracked totals of a period.
enum DayTotals {
    /// Sum of time entries, clipped to the range.
    static func registered(entries: [TimeEntry], in range: DateRange) -> TimeInterval {
        entries.reduce(0) { total, entry in
            total + (entry.range.intersection(with: range)?.duration ?? 0)
        }
    }

    /// Sum of app sessions, clipped to the range; an open session runs until `now`.
    static func tracked(sessions: [AppSession], in range: DateRange, now: Date) -> TimeInterval {
        sessions.reduce(0) { total, session in
            let end = session.end ?? now
            guard end > session.start else { return total }
            let sessionRange = DateRange(start: session.start, end: end)
            return total + (sessionRange.intersection(with: range)?.duration ?? 0)
        }
    }
}
