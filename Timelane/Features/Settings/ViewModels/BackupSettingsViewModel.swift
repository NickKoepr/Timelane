import Foundation

/// The backup part of the iCloud settings: what is in iCloud, Back Up Now and Restore.
@MainActor @Observable
final class BackupSettingsViewModel {
    var isConfirmingRestore = false
    var errorMessage: String?

    private let service: CloudBackupService

    init(service: CloudBackupService) {
        self.service = service
    }

    var isWorking: Bool { service.isWorking }
    /// Whether this device records (and backs up) app activity: the Mac.
    var showsActivity: Bool { service.backsUpActivity }
    /// A failure of the last (automatic or manual) run, or of the last settings action.
    var shownError: String? { errorMessage ?? service.lastError }
    var restoreCandidate: BackupInfo? { service.restorableProjects }

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
            try await service.restoreBackup()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    static func describe(_ info: BackupInfo) -> String { "\(date(info)) from \(info.deviceName)" }

    static func date(_ info: BackupInfo) -> String { info.createdAt.formatted(date: .abbreviated, time: .shortened) }

    static func counts(_ info: BackupInfo) -> String {
        "\(info.projectCount) projects, \(info.timeEntryCount) time entries"
    }
}
