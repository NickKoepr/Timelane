import Foundation

/// The remote side of the backup: one snapshot file plus its metadata per `BackupPart`. Implemented by
/// CloudKit (live) and an in-memory fake (tests, previews).
protocol CloudBackupStore: Sendable {
    func accountStatus() async throws -> CloudAccountStatus
    /// The metadata of the stored part, or nil when there is none. Does not download the file.
    func latestBackup(_ part: BackupPart) async throws -> BackupInfo?
    /// Replaces the stored part with this file.
    func upload(_ file: URL, info: BackupInfo, as part: BackupPart) async throws
    /// Downloads the stored part into a fresh temporary directory owned by the caller
    /// (the caller removes `file.deletingLastPathComponent()` when done). Nil when there is none.
    func download(_ part: BackupPart) async throws -> (file: URL, info: BackupInfo)?
    /// Removes the stored part; no error when there is none.
    func delete(_ part: BackupPart) async throws
}
