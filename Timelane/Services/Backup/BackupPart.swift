/// The records of the iCloud backup. All are `DatabaseBackup` records with the same fields in the private
/// database, so adding a part needs no CloudKit schema change; only the record name differs.
enum BackupPart: String, Sendable, CaseIterable {
    /// Projects and time entries: the data sync shares. Written by any device that is caught up with sync.
    case projectsAndHours
    /// App sessions and tracked apps (plus the projects they link to): Mac-only data that sync does not share.
    /// Written only by the Mac that owns it (`ActivityBackupOwnership`).
    case appActivity
    /// The whole-database backup of older versions (record `latest`). Read for restores, never written;
    /// removed by the legacy cleanup once nothing depends on it.
    case legacy

    var recordName: String { self == .legacy ? "latest" : rawValue }
}
