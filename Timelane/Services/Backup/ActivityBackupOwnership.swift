import Foundation

/// Whether this Mac may replace the app activity backup automatically: only when there is none, or when the one in
/// iCloud is the last one this Mac uploaded. A new or reinstalled Mac, or a second Mac, never overwrites another
/// Mac's activity by itself; the user chooses (restore it, or replace it).
enum ActivityBackupOwnership {
    static func mayReplace(remote: BackupInfo?, lastOwnUpload: Date?) -> Bool {
        guard let remote else { return true }
        guard let lastOwnUpload else { return false }
        // CloudKit keeps dates to the millisecond.
        return abs(remote.createdAt.timeIntervalSince(lastOwnUpload)) < 1
    }
}
