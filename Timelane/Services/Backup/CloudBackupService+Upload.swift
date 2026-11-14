import Foundation
import os

extension CloudBackupService {
    /// Uploads projects and hours. Waits (no upload, part stays dirty) until this device is caught up with sync, so a
    /// device that was closed for a while never uploads old data before it fetched. Automatic runs also keep a
    /// backup with data when this device has none (`BackupSafety`).
    func backUpProjects(automatic: Bool) async throws {
        projectsSkip = nil
        guard await sync.isCaughtUp() else {
            projectsSkip = .waitingForSync
            if !automatic { throw BackupError.waitingForSync }
            return
        }
        lastAttempt[.projectsAndHours] = now()
        try await requireAccount()
        dirty.remove(.projectsAndHours)          // a change during the upload marks it dirty again
        let (file, info, directory) = try await snapshot(.projectsAndHours)
        defer { try? FileManager.default.removeItem(at: directory) }
        if automatic {
            var existing = try await store.latestBackup(.projectsAndHours)
            if existing == nil { existing = try await store.latestBackup(.legacy) }
            guard BackupSafety.mayReplace(remote: existing, with: info, isAutomatic: true) else {
                projectsSkip = .emptyDevice
                Self.logger.notice("Skipped automatic backup: this device has no data and iCloud has a backup")
                return
            }
        }
        try await store.upload(file, info: info, as: .projectsAndHours)
        remote[.projectsAndHours] = info
        do {
            try await cleanUpLegacy()
        } catch {
            Self.logger.error("Legacy backup cleanup failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// Uploads the app activity of this Mac, unless another device owns the backup in iCloud and
    /// `replacingOtherDevice` is false (then `activityNotOwned` is set and nothing is uploaded).
    func backUpActivity(replacingOtherDevice: Bool) async throws {
        lastAttempt[.appActivity] = now()
        try await requireAccount()
        dirty.remove(.appActivity)
        let existing = try await store.latestBackup(.appActivity)
        guard replacingOtherDevice
              || ActivityBackupOwnership.mayReplace(remote: existing, lastOwnUpload: settings.activityUploadedAt) else {
            remote[.appActivity] = existing
            activityNotOwned = true
            return
        }
        let (file, info, directory) = try await snapshot(.appActivity)
        defer { try? FileManager.default.removeItem(at: directory) }
        try await store.upload(file, info: info, as: .appActivity)
        settings.activityUploadedAt = info.createdAt
        remote[.appActivity] = info
        activityNotOwned = false
    }

    /// Removes the whole-database backup of older versions once nothing depends on it: when an app activity backup
    /// exists, or when it holds no app activity (checked once per version of it).
    func cleanUpLegacy() async throws {
        guard let legacy = try await store.latestBackup(.legacy) else {
            remote[.legacy] = nil
            return
        }
        if try await store.latestBackup(.appActivity) == nil {
            if let checked = settings.legacyCheckedAt, abs(checked.timeIntervalSince(legacy.createdAt)) < 1 { return }
            guard let (file, _) = try await store.download(.legacy) else { return }
            defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
            let holdsActivity = try await Task.detached { try ActivityBackupMerger.containsActivity(file) }.value
            if holdsActivity {
                settings.legacyCheckedAt = legacy.createdAt     // the only copy of some Mac's activity: keep it
                return
            }
        }
        try await store.delete(.legacy)
        remote[.legacy] = nil
        Self.logger.notice("Removed the backup of an older Timelane version")
    }

    func snapshot(_ part: BackupPart) async throws -> (file: URL, info: BackupInfo, directory: URL) {
        let directory = Self.temporaryDirectory()
        let (snapshotter, name, version, date) = (snapshotter, deviceName, appVersion, now())
        let (file, info) = try await Task.detached {
            try snapshotter.makeSnapshot(part, in: directory, deviceName: name, appVersion: version, now: date)
        }.value
        return (file, info, directory)
    }
}
