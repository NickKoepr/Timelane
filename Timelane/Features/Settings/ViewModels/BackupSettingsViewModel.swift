import Foundation

@MainActor @Observable
final class BackupSettingsViewModel {
    /// Set while the user has to choose what to do with the backup that already exists in iCloud.
    var pendingChoice: BackupInfo?
    /// The backup a confirmed restore would use.
    var restoreCandidate: BackupInfo?
    var isConfirmingRestore = false
    var errorMessage: String?

    private let service: CloudBackupService
    private let relaunch: @MainActor () -> Void

    init(service: CloudBackupService, relaunch: @escaping @MainActor () -> Void) {
        self.service = service
        self.relaunch = relaunch
    }

    var isEnabled: Bool { service.isEnabled }
    var isWorking: Bool { service.isWorking }
    /// A failure of the last (automatic or manual) run, or of the last settings action.
    var shownError: String? { errorMessage ?? service.lastError }

    var statusText: String {
        if service.isWorking { return "Backing up…" }
        if service.skippedBecauseEmpty {
            return "Skipped: this Mac has no data yet; your iCloud backup was kept."
        }
        guard let last = service.lastBackupAt else { return "Not backed up yet" }
        return "Last backed up \(last.formatted(date: .abbreviated, time: .shortened))"
    }

    func setEnabled(_ enabled: Bool) async {
        errorMessage = nil
        guard enabled else {
            // Turning it off keeps the backup in iCloud.
            service.setEnabled(false)
            return
        }
        guard !service.isEnabled else { return }
        let status = await service.accountStatus()
        guard status == .available else {
            errorMessage = BackupError.iCloudUnavailable(status).errorDescription
            return
        }
        do {
            if let remote = try await service.latestRemoteBackup(), remote.hasData {
                pendingChoice = remote
                return
            }
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        service.setEnabled(true)
        await service.backUpNow(automatic: false)
    }

    func resolveChoice(_ choice: ExistingBackupChoice) async {
        pendingChoice = nil
        switch choice {
        case .cancel:
            break
        case .replace:
            service.setEnabled(true)
            await service.backUpNow(automatic: false)
        case .restore:
            service.setEnabled(true)
            await restoreAndRelaunch()
        }
    }

    func backUpNow() async {
        errorMessage = nil
        await service.backUpNow(automatic: false)
    }

    /// Looks up the backup and asks for confirmation (the view shows the dialog).
    func requestRestore() async {
        errorMessage = nil
        do {
            guard let remote = try await service.latestRemoteBackup() else { throw BackupError.noBackup }
            restoreCandidate = remote
            isConfirmingRestore = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func confirmRestore() async {
        isConfirmingRestore = false
        await restoreAndRelaunch()
    }

    private func restoreAndRelaunch() async {
        do {
            try await service.prepareRestore()
            relaunch()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
