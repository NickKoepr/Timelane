import Foundation
import Observation
import os

/// The backup half of the iCloud feature. While iCloud (sync) is on it keeps two parts up to date: projects and
/// hours (from any device, only when caught up with sync) and, on a Mac, the app activity (only by the Mac that owns
/// it). Automatic runs never throw at the UI: errors end up in `lastError`.
@MainActor @Observable
final class CloudBackupService {
    /// Why the last automatic backup of projects and hours did not upload.
    enum ProjectsSkip: Equatable {
        /// This device was not caught up with iCloud sync yet.
        case waitingForSync
        /// This device has no data and iCloud has a backup with data.
        case emptyDevice
    }

    var isWorking = false
    var lastError: String?
    var projectsSkip: ProjectsSkip?
    /// The remote parts as last seen (refreshed after uploads and by `refreshRemote`).
    var remote: [BackupPart: BackupInfo] = [:]
    /// The app activity backup in iCloud belongs to another device, so this Mac does not overwrite it by itself.
    var activityNotOwned = false
    /// Whether this device records app activity (macOS) and therefore backs it up.
    let backsUpActivity: Bool

    @ObservationIgnored var dirty: Set<BackupPart> = [.projectsAndHours, .appActivity]
    @ObservationIgnored var lastAttempt: [BackupPart: Date] = [:]
    let snapshotter: BackupSnapshotter
    let merger: ActivityBackupMerger
    let store: any CloudBackupStore
    let settings: any BackupSettingsStore
    let sync: any BackupSyncPartner
    /// Where the copy of the whole database is kept before a restore.
    let safetyCopy: URL
    let now: () -> Date
    private let projectChanges: () -> AsyncStream<Void>
    private let activityChanges: () -> AsyncStream<Void>
    let deviceName: String
    let appVersion: String
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Timelane", category: "backup")

    init(snapshotter: BackupSnapshotter, merger: ActivityBackupMerger, store: any CloudBackupStore,
         settings: any BackupSettingsStore, sync: any BackupSyncPartner, safetyCopy: URL, backsUpActivity: Bool,
         now: @escaping () -> Date = { .now },
         projectChanges: @escaping () -> AsyncStream<Void> = { AsyncStream { $0.finish() } },
         activityChanges: @escaping () -> AsyncStream<Void> = { AsyncStream { $0.finish() } },
         deviceName: String = "Mac", appVersion: String = "") {
        self.snapshotter = snapshotter
        self.merger = merger
        self.store = store
        self.settings = settings
        self.sync = sync
        self.safetyCopy = safetyCopy
        self.backsUpActivity = backsUpActivity
        self.now = now
        self.projectChanges = projectChanges
        self.activityChanges = activityChanges
        self.deviceName = deviceName
        self.appVersion = appVersion
    }

    var isEnabled: Bool { sync.isEnabled }

    /// The backup a restore of projects and hours would use: the current part, or an older version's backup.
    var restorableProjects: BackupInfo? { remote[.projectsAndHours] ?? remote[.legacy] }
    /// The app activity a restore would add on a Mac.
    var restorableActivity: BackupInfo? { remote[.appActivity] ?? remote[.legacy] }

    func markDirty(_ part: BackupPart) { dirty.insert(part) }

    func accountStatus() async -> CloudAccountStatus {
        (try? await store.accountStatus()) ?? .couldNotDetermine
    }

    /// Reads the metadata of every part (no downloads).
    func refreshRemote() async {
        do {
            try await requireAccount()
            var found: [BackupPart: BackupInfo] = [:]
            for part in BackupPart.allCases {
                if let info = try await store.latestBackup(part) { found[part] = info }
            }
            remote = found
            activityNotOwned = backsUpActivity
                && !ActivityBackupOwnership.mayReplace(remote: found[.appActivity], lastOwnUpload: settings.activityUploadedAt)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Runs the automatic backups the schedules allow. Nothing happens while iCloud is off.
    func tick() async {
        guard isEnabled, !isWorking else { return }
        let date = now()
        if BackupSchedule.projectsAndHours.shouldBackUp(
            now: date, isDirty: dirty.contains(.projectsAndHours), lastAttempt: lastAttempt[.projectsAndHours]) {
            await run { try await self.backUpProjects(automatic: true) }
        }
        if backsUpActivity, BackupSchedule.appActivity.shouldBackUp(
            now: date, isDirty: dirty.contains(.appActivity), lastAttempt: lastAttempt[.appActivity]) {
            await run { try await self.backUpActivity(replacingOtherDevice: false) }
        }
    }

    /// "Back Up Now": syncs first, then backs up both parts. Never overwrites another Mac's app activity.
    func backUpNow() async {
        guard isEnabled, !isWorking else { return }
        await sync.syncNow()
        await run {
            try await self.backUpProjects(automatic: false)
            if self.backsUpActivity { try await self.backUpActivity(replacingOtherDevice: false) }
        }
    }

    /// "Replace with This Mac's Activity": takes over the app activity backup from another device.
    func replaceActivityBackup() async {
        guard isEnabled, backsUpActivity, !isWorking else { return }
        await run { try await self.backUpActivity(replacingOtherDevice: true) }
    }

    /// The run loop: changes mark their part dirty, a minute timer asks the schedules.
    /// Both parts count as dirty at launch. Idle while iCloud is off; turning it on needs no restart.
    func run() async {
        let projectStream = projectChanges()
        let activityStream = activityChanges()
        let watchers = [
            Task { @MainActor [weak self] in for await _ in projectStream { self?.markDirty(.projectsAndHours) } },
            Task { @MainActor [weak self] in for await _ in activityStream { self?.markDirty(.appActivity) } },
        ]
        defer { watchers.forEach { $0.cancel() } }
        while !Task.isCancelled {
            await tick()
            try? await Task.sleep(for: .seconds(60))
        }
    }

    /// Runs one action with the shared busy/error state.
    func run(_ action: () async throws -> Void) async {
        isWorking = true
        lastError = nil
        defer { isWorking = false }
        do {
            try await action()
        } catch {
            lastError = error.localizedDescription
            Self.logger.error("Backup failed: \(String(describing: error), privacy: .public)")
        }
    }

    func requireAccount() async throws {
        let status = try await store.accountStatus()
        guard status == .available else { throw BackupError.iCloudUnavailable(status) }
    }

    static func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("TimelaneBackup", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}
