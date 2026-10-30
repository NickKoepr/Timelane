import Foundation

/// Where the backup preferences survive app restarts.
@MainActor
protocol BackupSettingsStore: AnyObject {
    var isEnabled: Bool { get set }
    var lastBackupAt: Date? { get set }
}

final class InMemoryBackupSettingsStore: BackupSettingsStore {
    var isEnabled: Bool
    var lastBackupAt: Date?
    init(isEnabled: Bool = false, lastBackupAt: Date? = nil) {
        self.isEnabled = isEnabled
        self.lastBackupAt = lastBackupAt
    }
}

final class UserDefaultsBackupSettingsStore: BackupSettingsStore {
    static let enabledKey = "iCloudBackup.isEnabled"
    static let lastBackupKey = "iCloudBackup.lastBackupAt"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var isEnabled: Bool {
        get { defaults.bool(forKey: Self.enabledKey) }
        set { defaults.set(newValue, forKey: Self.enabledKey) }
    }

    var lastBackupAt: Date? {
        get { defaults.object(forKey: Self.lastBackupKey) as? Date }
        set {
            if let newValue { defaults.set(newValue, forKey: Self.lastBackupKey) } else { defaults.removeObject(forKey: Self.lastBackupKey) }
        }
    }
}
