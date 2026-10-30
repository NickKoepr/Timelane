import Foundation
import Observation
import os

/// Opt-in iCloud backup of the whole database. Automatic runs never throw at the UI: errors end up in `lastError`.
@MainActor @Observable
final class CloudBackupService {
    private(set) var isEnabled: Bool
    private(set) var lastBackupAt: Date?
    private(set) var isWorking = false
    private(set) var lastError: String?
    /// The last automatic backup was skipped to keep an iCloud backup that holds data.
    private(set) var skippedBecauseEmpty = false
    private(set) var isDirty = false
    private var lastAttempt: Date?

    private let snapshotter: BackupSnapshotter
    private let store: any CloudBackupStore
    private let settings: any BackupSettingsStore
    private let pendingRestore: PendingRestore
    private let schedule: BackupSchedule
    private let now: () -> Date
    private let changes: () -> AsyncStream<Void>
    private let deviceName: String
    private let appVersion: String
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Timelane", category: "backup")

    init(snapshotter: BackupSnapshotter, store: any CloudBackupStore, settings: any BackupSettingsStore,
         pendingRestore: PendingRestore, schedule: BackupSchedule = BackupSchedule(),
         now: @escaping () -> Date = { .now }, changes: @escaping () -> AsyncStream<Void> = { AsyncStream { $0.finish() } },
         deviceName: String = "Mac", appVersion: String = "") {
        self.snapshotter = snapshotter
        self.store = store
        self.settings = settings
        self.pendingRestore = pendingRestore
        self.schedule = schedule
        self.now = now
        self.changes = changes
        self.deviceName = deviceName
        self.appVersion = appVersion
        self.isEnabled = settings.isEnabled
        self.lastBackupAt = settings.lastBackupAt
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        settings.isEnabled = enabled
        if enabled { isDirty = true }
    }

    func markDirty() { isDirty = true }

    func accountStatus() async -> CloudAccountStatus {
        (try? await store.accountStatus()) ?? .couldNotDetermine
    }

    func latestRemoteBackup() async throws -> BackupInfo? {
        try await store.latestBackup()
    }

    /// Uploads a snapshot. `automatic` runs are subject to `BackupSafety`; manual ones always replace.
    func backUpNow(automatic: Bool) async {
        guard !isWorking, !pendingRestore.hasPendingRestore else { return }
        isWorking = true
        lastError = nil
        skippedBecauseEmpty = false
        lastAttempt = now()
        defer { isWorking = false }
        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        do {
            let status = try await store.accountStatus()
            guard status == .available else { throw BackupError.iCloudUnavailable(status) }
            let (snapshotter, name, version, date) = (snapshotter, deviceName, appVersion, now())
            let (file, info) = try await Task.detached {
                try snapshotter.makeSnapshot(in: directory, deviceName: name, appVersion: version, now: date)
            }.value
            if automatic {
                let remote = try await store.latestBackup()
                guard BackupSafety.mayReplace(remote: remote, with: info, isAutomatic: true) else {
                    skippedBecauseEmpty = true
                    isDirty = false
                    Self.logger.notice("Skipped automatic backup: this Mac has no data and iCloud has a backup")
                    return
                }
            }
            try await store.upload(file, info: info)
            isDirty = false
            lastBackupAt = info.createdAt
            settings.lastBackupAt = info.createdAt
        } catch {
            lastError = error.localizedDescription
            Self.logger.error("Backup failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// Downloads the iCloud backup, validates it and stages it; it replaces the database on the next launch.
    func prepareRestore() async throws {
        guard let (file, _) = try await store.download() else { throw BackupError.noBackup }
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        try pendingRestore.stage(file)
    }

    /// Runs `backUpNow(automatic: true)` when the schedule allows it.
    func tick() async {
        guard schedule.shouldBackUp(now: now(), isEnabled: isEnabled, isDirty: isDirty, lastAttempt: lastAttempt) else { return }
        await backUpNow(automatic: true)
    }

    /// The run loop: database changes mark the data dirty, a minute timer asks the schedule.
    /// The first tick after launch counts as dirty. Idle while backup is off; turning it on needs no restart.
    func run() async {
        isDirty = true
        let stream = changes()
        let watcher = Task { @MainActor [weak self] in
            for await _ in stream { self?.markDirty() }
        }
        defer { watcher.cancel() }
        while !Task.isCancelled {
            await tick()
            try? await Task.sleep(for: .seconds(60))
        }
    }

    private static func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("TimelaneBackup", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}
