import Foundation

/// Single place for the way durations are shown (could become a preference later).
enum DurationFormatter {
    /// "3:45" — hours:minutes, rounded to the nearest minute.
    static func hoursMinutes(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int((max(seconds, 0) / 60).rounded())
        return String(format: "%d:%02d", totalMinutes / 60, totalMinutes % 60)
    }

    /// "3h 45m", "45m" — compact form for small labels.
    static func short(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int((max(seconds, 0) / 60).rounded())
        let hours = totalMinutes / 60, minutes = totalMinutes % 60
        if hours == 0 { return "\(minutes)m" }
        return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
    }
}
