import Foundation

/// Whether this Mac may replace the app activity backup as it is: only when there is none, or when the one in iCloud
/// is the last one this Mac uploaded. Otherwise (a new Mac, or a second one) the activity in iCloud is added to this
/// Mac first, so replacing the backup never loses it.
enum ActivityBackupOwnership {
    static func mayReplace(remote: BackupInfo?, lastOwnUpload: Date?) -> Bool {
        guard let remote else { return true }
        guard let lastOwnUpload else { return false }
        // CloudKit keeps dates to the millisecond.
        return abs(remote.createdAt.timeIntervalSince(lastOwnUpload)) < 1
    }
}
