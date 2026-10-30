/// Protects a good backup from being replaced by an empty database (e.g. after a reinstall).
enum BackupSafety {
    /// False only when an automatic backup of an empty database would replace a backup that holds data.
    /// Manual actions are always allowed (the UI asks for confirmation).
    static func mayReplace(remote: BackupInfo?, with local: BackupInfo, isAutomatic: Bool) -> Bool {
        !(isAutomatic && remote?.hasData == true && !local.hasData)
    }
}
