import Foundation

/// The iCloud switch (sync + backup) and the sync status in Settings.
@MainActor @Observable
final class SyncSettingsViewModel {
    /// Set while the user has to choose what to do with the data that already exists in iCloud (A1/A3).
    var isChoosingExistingData = false
    /// Set while turning iCloud on finds no synced data but a backup with data: restore it or start from this device.
    var backupOffer: BackupInfo?
    /// Set while the user has to confirm turning sync off (A4).
    var isConfirmingDisable = false
    /// True while checking iCloud and turning sync on.
    private(set) var isEnabling = false
    var errorMessage: String?

    private let service: SyncService
    private let backup: CloudBackupService

    init(service: SyncService, backup: CloudBackupService) {
        self.service = service
        self.backup = backup
    }

    var isEnabled: Bool { service.isEnabled }
    var isBusy: Bool { isEnabling || service.isSyncing }
    /// An account message (A5) or a customer id notice (C3).
    var notices: [String] { [service.notice, service.customIdNotice].compactMap { $0 } }
    var shownError: String? { errorMessage }

    var statusText: String {
        switch service.status {
        case .off: "Off"
        case .syncing: "Syncing…"
        case .idle(let last):
            if let last { "Last synced \(last.formatted(date: .abbreviated, time: .shortened))" } else { "Waiting for the first sync" }
        case .paused(let reason): "Sync paused: \(reason)"
        case .needsAppUpdate: "Update Timelane on this device to keep syncing"
        case .error(let message): "Sync failed: \(message)"
        }
    }

    /// The toggle was switched. Turning on may show the A1 dialog first; turning off asks for confirmation.
    func setEnabled(_ enabled: Bool) async {
        errorMessage = nil
        guard enabled else {
            if service.isEnabled { isConfirmingDisable = true }
            return
        }
        guard !service.isEnabled, !isEnabling else { return }
        isEnabling = true
        defer { isEnabling = false }
        do {
            let status = try await service.accountStatus()
            guard status == .available else {
                errorMessage = Self.unavailableMessage(status)
                return
            }
            if try await service.remoteHasData() {
                isChoosingExistingData = true       // always ask, also when this device is empty
                return
            }
            await backup.refreshRemote()
            if let offer = backup.restorableProjects, offer.hasData {
                backupOffer = offer
                return
            }
            try await service.enable(.replaceICloud)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    static func unavailableMessage(_ status: CloudAccountStatus) -> String {
        switch status {
        case .restricted: "iCloud is restricted on \(DeviceKind.current.thisDevice), so Timelane cannot sync."
        case .temporarilyUnavailable: "iCloud is temporarily unavailable. Try again later."
        case .couldNotDetermine: "Timelane could not reach iCloud. Try again later."
        default: "Sign in to iCloud in \(DeviceKind.current.systemSettingsName) to use iCloud."
        }
    }

    func resolveChoice(_ choice: ExistingSyncDataChoice) async {
        isChoosingExistingData = false
        let enableChoice: SyncEnableChoice
        switch choice {
        case .cancel: return
        case .replaceICloud: enableChoice = .replaceICloud
        case .replaceLocal: enableChoice = .replaceLocal
        }
        isEnabling = true
        defer { isEnabling = false }
        do {
            try await service.enable(enableChoice)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// The answer to the backup offer: restore the backup (then it becomes the iCloud data) or use this device's data.
    func resolveBackupOffer(_ choice: ExistingBackupChoice) async {
        backupOffer = nil
        guard choice != .cancel else { return }
        isEnabling = true
        defer { isEnabling = false }
        do {
            if choice == .restore { try await backup.restoreProjects() }
            try await service.enable(.replaceICloud)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func confirmDisable() async {
        isConfirmingDisable = false
        await service.disable()
    }

    func syncNow() async {
        errorMessage = nil
        await service.syncNow()
    }
}
