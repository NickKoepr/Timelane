import Foundation

/// The backup part of the iCloud settings: what is in iCloud, Back Up Now and Restore.
@MainActor @Observable
final class BackupSettingsViewModel {
    var isConfirmingRestore = false
    var errorMessage: String?
    /// What the last restore added to the app activity (Mac).
    var restoreMessage: String?

    private let service: CloudBackupService

    init(service: CloudBackupService) {
        self.service = service
    }

    var isWorking: Bool { service.isWorking }
    /// The app activity rows exist only where activity is recorded (the Mac).
    var showsActivity: Bool { service.backsUpActivity }
    var activityNotOwned: Bool { service.activityNotOwned }
    /// A failure of the last (automatic or manual) run, or of the last settings action.
    var shownError: String? { errorMessage ?? service.lastError }
    var restoreCandidate: BackupInfo? { service.restorableProjects }
    /// The app activity a restore adds (Mac); nil when there is none or this device has no app activity.
    var activityCandidate: BackupInfo? { showsActivity ? service.restorableActivity : nil }

    var projectsStatusText: String {
        if service.isWorking { return "Backing up…" }
        if service.projectsSkip == .emptyDevice {
            return "Skipped: \(DeviceKind.current.thisDevice) has no data yet; your iCloud backup was kept."
        }
        if let info = service.remote[.projectsAndHours] {
            return "Latest backup \(Self.describe(info)) · \(Self.counts(info))"
        }
        if let legacy = service.remote[.legacy] {
            return "Backup of an older Timelane version \(Self.describe(legacy))"
        }
        return "No backup yet"
    }

    var activityStatusText: String {
        guard let info = service.remote[.appActivity] else {
            if let legacy = service.remote[.legacy] { return "In the backup of an older Timelane version \(Self.describe(legacy))" }
            return "No app activity backup yet"
        }
        if service.activityNotOwned {
            return "The app activity backup in iCloud is from \(info.deviceName) (\(Self.date(info))). The activity of "
                + "\(DeviceKind.current.thisDevice) is not backed up until you restore the backup or replace it."
        }
        return "Latest backup \(Self.describe(info))"
    }

    func task() async {
        await service.refreshRemote()
    }

    func backUpNow() async {
        errorMessage = nil
        await service.backUpNow()
    }

    /// Looks up the backup and asks for confirmation (the view shows the dialog).
    func requestRestore() async {
        errorMessage = nil
        restoreMessage = nil
        await service.refreshRemote()
        guard service.lastError == nil else { return }          // shown through `shownError`
        guard restoreCandidate != nil else {
            errorMessage = BackupError.noBackup.errorDescription
            return
        }
        isConfirmingRestore = true
    }

    func confirmRestore() async {
        isConfirmingRestore = false
        do {
            if let added = try await service.restoreBackup() {
                restoreMessage = "Restored. Added \(added.sessions) app sessions and \(added.trackedApps) tracked apps "
                    + "that were missing on \(DeviceKind.current.thisDevice)."
            } else if service.lastError == nil {
                restoreMessage = "Restored."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func replaceActivityBackup() async {
        errorMessage = nil
        await service.replaceActivityBackup()
    }

    static func describe(_ info: BackupInfo) -> String { "\(date(info)) from \(info.deviceName)" }

    static func date(_ info: BackupInfo) -> String { info.createdAt.formatted(date: .abbreviated, time: .shortened) }

    static func counts(_ info: BackupInfo) -> String {
        "\(info.projectCount) projects, \(info.timeEntryCount) time entries"
    }
}
