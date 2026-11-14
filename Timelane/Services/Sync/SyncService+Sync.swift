import Foundation

extension SyncService {
    /// Fetches, then sends, until nothing changes any more (at most a few rounds). Downloaded changes can
    /// produce corrections that must be sent, and a conflict makes a record go up a second time.
    /// A call while a pass is running is not dropped: the running pass does another round.
    func syncNow() async {
        guard isEnabled else { return }
        if !isEngineRunning { await startEngine() }     // an earlier start may have failed
        guard isEngineRunning else { return }
        guard !isSyncing else {
            syncRequested = true
            return
        }
        isSyncing = true
        pauseReason = nil
        errorMessage = nil
        defer { isSyncing = false }

        for _ in 0..<8 {
            guard isEnabled else { return }     // an event may have turned sync off (sign-out, zone removed)
            syncRequested = false
            let eventsBefore = eventCount
            do {
                if remoteResetPending {
                    try await followRemoteReset()
                    guard isEnabled else { return }
                }
                try await engine.fetchChanges()
                if remoteResetPending { continue }      // found during this fetch: reset first, send nothing
                let outbox = try await store.pendingOutbox()
                await forward(outbox)
                try await engine.sendChanges()
            } catch {
                report(error)
                return
            }
            if pauseReason != nil || errorMessage != nil { return }
            if eventCount == eventsBefore && !remoteResetPending && !syncRequested { break }
        }
        // A pass that found nothing new still checked iCloud: show that in "Last synced".
        if isEnabled { await markSynced() }
    }

    /// Runs `syncNow` soon, for follow-up work found inside an engine event or after local changes.
    /// While a sync is running the request is remembered and picked up by that pass.
    func scheduleSync() {
        guard !isSyncing else {
            syncRequested = true
            return
        }
        Task { [weak self] in await self?.syncNow() }
    }
}
