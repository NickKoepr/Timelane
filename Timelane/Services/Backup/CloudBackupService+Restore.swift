import Foundation

extension CloudBackupService {
    /// Restores the backup: the projects and hours (the current part, else an older version's whole-database backup)
    /// replace those on every device; on a Mac the app activity from the backup that this Mac is missing is added
    /// too (nothing is removed). A copy of the whole database is kept first (`safetyCopy`).
    func restoreBackup() async throws {
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
        guard backsUpActivity else { return }
        // Projects and hours are restored now; a failure below must not look like the whole restore failed.
        do {
            try await restoreActivity()
        } catch {
            lastError = "Projects and hours were restored, but app activity could not be: \(error.localizedDescription)"
        }
    }

    private func restoreActivity() async throws {
        if try await store.latestBackup(.appActivity) != nil {
            try await mergeActivity(from: .appActivity)
        } else if try await store.latestBackup(.legacy) != nil {
            try await mergeActivity(from: .legacy)
        } else {
            return
        }
        try await uploadActivity()
    }

    func downloadValidated(_ part: BackupPart) async throws -> URL {
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
