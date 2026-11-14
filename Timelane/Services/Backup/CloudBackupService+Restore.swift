import Foundation

extension CloudBackupService {
    /// Restores the backup: the projects and hours (the current part, else an older version's whole-database backup)
    /// replace those on every device; on a Mac the app activity from the backup that this Mac is missing is added
    /// too (nothing is removed) and this Mac becomes the owner of the activity backup. A copy of the whole database
    /// is kept first (`safetyCopy`). Returns what was added to the app activity (nil where there is none).
    @discardableResult
    func restoreBackup() async throws -> ActivityBackupMerger.Result? {
        guard !isWorking else { return nil }
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
        guard backsUpActivity else { return nil }
        // Projects and hours are restored now; a failure below must not look like the whole restore failed.
        do {
            return try await restoreActivity()
        } catch {
            lastError = "Projects and hours were restored, but app activity could not be: \(error.localizedDescription)"
            return nil
        }
    }

    /// Adds the app activity of the backup this Mac is missing, then backs up the combined activity.
    private func restoreActivity() async throws -> ActivityBackupMerger.Result {
        let part: BackupPart
        if try await store.latestBackup(.appActivity) != nil {
            part = .appActivity
        } else if try await store.latestBackup(.legacy) != nil {
            part = .legacy
        } else {
            return ActivityBackupMerger.Result()        // nothing to add
        }
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
