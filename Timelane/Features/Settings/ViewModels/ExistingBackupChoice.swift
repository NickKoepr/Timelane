/// What the user picks when turning iCloud on while iCloud holds a backup but no synced data.
enum ExistingBackupChoice {
    /// Restore the backup on this device; it then becomes the iCloud data.
    case restore
    /// Keep this device's data and upload it (the backup is replaced by later backups).
    case replace
    case cancel
}
