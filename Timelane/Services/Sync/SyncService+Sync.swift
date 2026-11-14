import Foundation

extension SyncService {
    /// Fetches, then sends, until nothing changes any more (at most a few rounds). Downloaded changes can
    /// produce corrections that must be sent, and a conflict makes a record go up a second time.
    func syncNow() async {
        guard isEnabled, isEngineRunning, !isSyncing else { return }
        isSyncing = true
        pauseReason = nil
        errorMessage = nil
        defer { isSyncing = false }

        for _ in 0..<8 {
            let eventsBefore = eventCount
            do {
                if zoneResetPending { try await recreateZoneAndUploadAll() }
                try await engine.fetchChanges()
                let outbox = try await store.pendingOutbox()
                await forward(outbox)
                try await engine.sendChanges()
            } catch {
                report(error)
                return
            }
            if pauseReason != nil || errorMessage != nil { return }
            if eventCount == eventsBefore && !zoneResetPending { break }
        }
    }

    /// Runs `syncNow` soon, for follow-up work found inside an engine event (not while a sync is running: it picks the work up itself).
    func scheduleSync() {
        guard !isSyncing else { return }
        Task { [weak self] in await self?.syncNow() }
    }

    /// The zone vanished (E5/zoneNotFound): create it again and send everything.
    func recreateZoneAndUploadAll() async throws {
        zoneResetPending = false
        isResettingZone = true
        defer { isResettingZone = false }
        try await store.clearAllSystemFields()
        try await store.setState(.engineState, nil)
        try await engine.deleteZoneAndRecreate()
        try await store.queueSaves(store.allRecords().map(\.id))
    }
}
