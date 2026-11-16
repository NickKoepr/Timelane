import Foundation

extension AppEnvironment {
    static func makeBackup(database: AppDatabase, store: any CloudBackupStore, settings: any BackupSettingsStore,
                           sync: SyncService, safetyCopy: URL) -> CloudBackupService {
        let info = Bundle.main.infoDictionary
        let version = [info?["CFBundleShortVersionString"] as? String, info?["CFBundleVersion"] as? String]
            .compactMap { $0 }.joined(separator: " (") + (info?["CFBundleVersion"] == nil ? "" : ")")
        #if os(macOS)
        let backsUpActivity = true      // only the Mac records app activity
        #else
        let backsUpActivity = false
        #endif
        return CloudBackupService(
            snapshotter: BackupSnapshotter(database: database), merger: ActivityBackupMerger(database: database),
            store: store, settings: settings, sync: sync, safetyCopy: safetyCopy, backsUpActivity: backsUpActivity,
            projectChanges: { database.changes(tables: ["project", "timeEntry"]) },
            activityChanges: { database.changes(tables: ["appSession", "trackedApp"]) },
            deviceName: isRunningTests ? "Mac" : DeviceName.current, appVersion: version)
    }

    /// After `sync.load()`: tells a device that had only the old backup switch on that it now needs iCloud.
    func runICloudMigration() {
        iCloudNotice = ICloudMigration.run(settings: backupSettings, isSyncEnabled: sync.isEnabled)
    }
}
