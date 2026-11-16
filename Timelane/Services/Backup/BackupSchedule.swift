import Foundation

/// When an automatic backup of one part may run: something changed, and not too soon after the last attempt.
struct BackupSchedule: Sendable {
    var minimumInterval: TimeInterval

    static let projectsAndHours = BackupSchedule(minimumInterval: 15 * 60)
    /// App activity changes all day long; once an hour is enough.
    static let appActivity = BackupSchedule(minimumInterval: 60 * 60)

    func shouldBackUp(now: Date, isDirty: Bool, lastAttempt: Date?) -> Bool {
        guard isDirty else { return false }
        guard let lastAttempt else { return true }
        return now.timeIntervalSince(lastAttempt) >= minimumInterval
    }
}
