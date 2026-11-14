import Foundation

/// Restoring a backup while iCloud is on, and the "caught up" check the backup waits for.
/// A restore replaces the local projects and hours, then the iCloud data (zone deleted and uploaded again), so
/// every other device follows through `SyncService+Reset`. `restoreUploadPending` (in memory and in `syncState`)
/// makes an interrupted restore finish first on the next launch or sync pass.
extension SyncService {
    /// True when a backup of projects and hours would match iCloud: this device finished a sync pass since launch,
    /// sent everything, and nothing (pause, error, reset, newer records) is in the way.
    func isCaughtUp() async -> Bool {
        guard isEnabled, isEngineRunning, completedPassSinceLaunch, !isSyncing, pauseReason == nil, errorMessage == nil,
              !remoteResetPending, !restoreUploadPending, !hasRecordsFromNewerApp else { return false }
        guard let outbox = try? await store.pendingOutbox() else { return false }
        return outbox.isEmpty
    }

    /// Replaces the local projects and hours with a validated backup file. With sync on, the iCloud data is replaced
    /// too; with sync off (the turn-on dialog) the caller turns sync on with `.replaceICloud` afterwards.
    func restore(fromBackup file: URL) async throws {
        guard isEnabled else {
            try await store.restoreSyncedData(from: file, uploadPending: false)
            onLocalDataReplaced()
            return
        }
        await stopEngine()
        try await store.restoreSyncedData(from: file, uploadPending: true)
        restoreUploadPending = true
        onLocalDataReplaced()
        isSyncing = true
        defer { isSyncing = false }
        try await replaceICloudAfterRestore()
        isSyncing = false
        await syncNow()
    }

    /// Uploads the restored data as the new iCloud data. The engine starts fresh so it never follows its own reset.
    func replaceICloudAfterRestore() async throws {
        guard restoreUploadPending else { return }
        await stopEngine()
        try await store.setState(.engineState, nil)
        await startEngine()
        guard isEngineRunning else { throw SyncEngineError.other(errorMessage ?? "Could not start iCloud sync.") }
        try await uploadEverything()
        try await store.setState(.restoreUploadPending, nil)
        restoreUploadPending = false
    }
}
