import Foundation

/// Older versions had a separate "Back up to iCloud" switch. Backups are now part of the one iCloud switch (sync),
/// so a device with backup on and sync off no longer backs up. Run once after sync loaded its state.
@MainActor
enum ICloudMigration {
    static let backupMovedNotice = "iCloud backup is now part of iCloud: turn on iCloud in Settings to keep backing up "
        + "and to keep your data the same on all your devices. Your existing backup stays in iCloud."

    /// Returns the notice to show once, if any, and forgets the old switch.
    static func run(settings: any BackupSettingsStore, isSyncEnabled: Bool) -> String? {
        let notice = settings.legacyBackupEnabled && !isSyncEnabled ? backupMovedNotice : nil
        settings.removeLegacyKeys()
        return notice
    }
}
