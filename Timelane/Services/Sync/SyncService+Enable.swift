import Foundation

/// Turning sync on and off. The caller (Settings) asks the user first (A1) and passes the choice.
extension SyncService {
    /// Whether iCloud already holds synced data. Works before sync is on, so the dialog can be shown first.
    func remoteHasData() async throws -> Bool {
        try await engine.zoneHasRecords()
    }

    func localHasData() async throws -> Bool {
        try await store.hasSyncedData()
    }

    func accountStatus() async throws -> CloudAccountStatus {
        try await engine.accountStatus()
    }

    /// Turns sync on. Always starts from a clean slate (A4): old sync metadata is dropped first.
    /// - `.replaceICloud`: iCloud is emptied when it has data, then every local project and entry is uploaded (A2 uses this too).
    /// - `.replaceLocal`: local projects and entries are wiped and replaced by what iCloud has.
    /// Throws (and leaves sync off) when iCloud cannot be reached.
    func enable(_ choice: SyncEnableChoice) async throws {
        guard !isolated, !isEnabled else { return }
        notice = nil
        errorMessage = nil
        pauseReason = nil
        isSyncing = true
        do {
            try await store.wipeSyncMetadata()
            try await store.setState(.enabled, Data([1]))
            isEnabled = true
            await startEngine()
            guard isEngineRunning else { throw SyncEngineError.other(errorMessage ?? "Could not start iCloud sync.") }
            switch choice {
            case .replaceICloud: try await uploadEverything()
            case .replaceLocal: try await downloadEverything()
            }
        } catch {
            isSyncing = false
            await disable()
            throw error
        }
        isSyncing = false
        await syncNow()
    }

    private func uploadEverything() async throws {
        if try await engine.zoneHasRecords() {
            isResettingZone = true
            defer { isResettingZone = false }
            try await store.setState(.engineState, nil)
            try await engine.deleteZoneAndRecreate()
        }
        let ids = try await store.allRecords().map(\.id)
        try await store.queueSaves(ids)
    }

    private func downloadEverything() async throws {
        let links = try await store.wipeLocalSyncedData()
        try await engine.fetchChanges()
        try await store.relinkTrackedApps(links)
    }

    /// Turns sync off and forgets all sync metadata; local data and iCloud data stay (A4). `notice` explains why, if sync stopped by itself.
    func disable(notice: String? = nil) async {
        await stopEngine()
        try? await store.wipeSyncMetadata()
        isEnabled = false
        isSyncing = false
        lastSync = nil
        pauseReason = nil
        errorMessage = nil
        hasRecordsFromNewerApp = false
        self.notice = notice
    }
}
