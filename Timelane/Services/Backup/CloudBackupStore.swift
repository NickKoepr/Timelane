import Foundation

/// The remote side of the backup: one snapshot file plus its metadata. Implemented by CloudKit (live)
/// and an in-memory fake (tests, previews).
protocol CloudBackupStore: Sendable {
    func accountStatus() async throws -> CloudAccountStatus
    /// The metadata of the stored backup, or nil when there is none. Does not download the file.
    func latestBackup() async throws -> BackupInfo?
    func upload(_ file: URL, info: BackupInfo) async throws
    /// Downloads the stored backup into a fresh temporary directory owned by the caller
    /// (the caller removes `file.deletingLastPathComponent()` when done). Nil when there is none.
    func download() async throws -> (file: URL, info: BackupInfo)?
}
