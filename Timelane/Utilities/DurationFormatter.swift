import Foundation

/// Single place for the way durations are shown (could become a preference later).
enum DurationFormatter {
    /// Whole minutes, rounded to the nearest minute (the basis of every shown duration).
    static func minutes(_ seconds: TimeInterval) -> Int { Int((max(seconds, 0) / 60).rounded()) }

    /// "3:45" — hours:minutes, rounded to the nearest minute.
    static func hoursMinutes(_ seconds: TimeInterval) -> String {
        let totalMinutes = minutes(seconds)
        return String(format: "%d:%02d", totalMinutes / 60, totalMinutes % 60)
    }

    /// "3h 45m", "45m" — compact form for small labels.
    static func short(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int((max(seconds, 0) / 60).rounded())
        let hours = totalMinutes / 60, minutes = totalMinutes % 60
        if hours == 0 { return "\(minutes)m" }
        return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
    }

    /// "0:12:34" — hours:minutes:seconds, for the running timer.
    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(max(seconds, 0))
        return String(format: "%d:%02d:%02d", total / 3600, total / 60 % 60, total % 60)
    }
}
