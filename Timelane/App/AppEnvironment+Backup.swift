import Foundation

extension AppEnvironment {
    static func makeBackup(database: AppDatabase, store: any CloudBackupStore, settings: any BackupSettingsStore,
                           pendingRestore: PendingRestore) -> CloudBackupService {
        let info = Bundle.main.infoDictionary
        let version = [info?["CFBundleShortVersionString"] as? String, info?["CFBundleVersion"] as? String]
            .compactMap { $0 }.joined(separator: " (") + (info?["CFBundleVersion"] == nil ? "" : ")")
        return CloudBackupService(
            snapshotter: BackupSnapshotter(database: database), store: store, settings: settings,
            pendingRestore: pendingRestore, changes: { database.changes() },
            deviceName: isRunningTests ? "Mac" : (Host.current().localizedName ?? "Mac"), appVersion: version)
    }
}
