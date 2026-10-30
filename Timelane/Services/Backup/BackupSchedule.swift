import Foundation

/// When an automatic backup may run: enabled, something changed, and not too soon after the last attempt.
struct BackupSchedule: Sendable {
    var minimumInterval: TimeInterval = 15 * 60

    func shouldBackUp(now: Date, isEnabled: Bool, isDirty: Bool, lastAttempt: Date?) -> Bool {
        guard isEnabled, isDirty else { return false }
        guard let lastAttempt else { return true }
        return now.timeIntervalSince(lastAttempt) >= minimumInterval
    }
}
