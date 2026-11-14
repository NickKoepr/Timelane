import Foundation

/// What the backup needs from iCloud sync: one switch turns both on, a backup of projects and hours waits until
/// this device is caught up, and restoring one goes through sync so every device follows.
@MainActor
protocol BackupSyncPartner: AnyObject {
    var isEnabled: Bool { get }
    func isCaughtUp() async -> Bool
    func syncNow() async
    func restore(fromBackup file: URL) async throws
}

extension SyncService: BackupSyncPartner {}
