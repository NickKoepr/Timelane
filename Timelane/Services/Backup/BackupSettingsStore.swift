import Foundation

/// Small backup bookkeeping that survives app restarts (per device).
@MainActor
protocol BackupSettingsStore: AnyObject {
    /// `createdAt` of the last app activity backup this device uploaded: it owns the remote one while they match.
    var activityUploadedAt: Date? { get set }
    /// `createdAt` of the legacy backup that was checked and must be kept (it holds app activity).
    var legacyCheckedAt: Date? { get set }
    /// The separate "Back up to iCloud" switch of older versions (read once by `ICloudMigration`).
    var legacyBackupEnabled: Bool { get }
    func removeLegacyKeys()
}

final class InMemoryBackupSettingsStore: BackupSettingsStore {
    var activityUploadedAt: Date?
    var legacyCheckedAt: Date?
    private(set) var legacyBackupEnabled: Bool

    init(legacyBackupEnabled: Bool = false) { self.legacyBackupEnabled = legacyBackupEnabled }

    func removeLegacyKeys() { legacyBackupEnabled = false }
}

final class UserDefaultsBackupSettingsStore: BackupSettingsStore {
    static let activityUploadedKey = "iCloudBackup.activityUploadedAt"
    static let legacyCheckedKey = "iCloudBackup.legacyCheckedAt"
    /// Keys of older versions.
    static let legacyEnabledKey = "iCloudBackup.isEnabled"
    static let legacyLastBackupKey = "iCloudBackup.lastBackupAt"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var activityUploadedAt: Date? {
        get { defaults.object(forKey: Self.activityUploadedKey) as? Date }
        set { set(newValue, forKey: Self.activityUploadedKey) }
    }

    var legacyCheckedAt: Date? {
        get { defaults.object(forKey: Self.legacyCheckedKey) as? Date }
        set { set(newValue, forKey: Self.legacyCheckedKey) }
    }

    var legacyBackupEnabled: Bool { defaults.bool(forKey: Self.legacyEnabledKey) }

    func removeLegacyKeys() {
        defaults.removeObject(forKey: Self.legacyEnabledKey)
        defaults.removeObject(forKey: Self.legacyLastBackupKey)
    }

    private func set(_ date: Date?, forKey key: String) {
        if let date { defaults.set(date, forKey: key) } else { defaults.removeObject(forKey: key) }
    }
}
