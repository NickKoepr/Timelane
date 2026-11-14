import Foundation

extension CloudBackupService {
    /// Replaces the projects and hours with the backup (the current part, else an older version's whole-database
    /// backup). With iCloud on this replaces them on every device; app activity is not touched. A copy of the whole
    /// database is kept first (`safetyCopy`).
    func restoreProjects() async throws {
        guard !isWorking else { return }
        isWorking = true
        lastError = nil
        defer { isWorking = false }
        try await requireAccount()
        let part: BackupPart = try await store.latestBackup(.projectsAndHours) != nil ? .projectsAndHours : .legacy
        let file = try await downloadValidated(part)
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let (snapshotter, safetyCopy) = (snapshotter, safetyCopy)
        try await Task.detached { try snapshotter.copyWholeDatabase(to: safetyCopy) }.value
        try await sync.restore(fromBackup: file)
        projectsSkip = nil
    }

    /// Adds the app activity from the backup that this Mac is missing (nothing is removed), then backs up the
    /// combined activity, which makes this Mac the owner of the app activity backup.
    @discardableResult
    func restoreActivity() async throws -> ActivityBackupMerger.Result {
        guard backsUpActivity, !isWorking else { return ActivityBackupMerger.Result() }
        isWorking = true
        lastError = nil
        defer { isWorking = false }
        try await requireAccount()
        let part: BackupPart = try await store.latestBackup(.appActivity) != nil ? .appActivity : .legacy
        let file = try await downloadValidated(part)
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let merger = merger
        let result = try await Task.detached { try merger.merge(from: file) }.value
        try await backUpActivity(replacingOtherDevice: true)
        return result
    }

    private func downloadValidated(_ part: BackupPart) async throws -> URL {
        guard let (file, _) = try await store.download(part) else { throw BackupError.noBackup }
        do {
            try await Task.detached { try BackupFileValidator.validateAndMigrate(file) }.value
        } catch {
            try? FileManager.default.removeItem(at: file.deletingLastPathComponent())
            throw error
        }
        return file
    }
}
