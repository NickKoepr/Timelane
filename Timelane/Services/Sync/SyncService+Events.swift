import Foundation

/// Reactions to what the engine reports.
extension SyncService {
    func handle(_ event: SyncEngineEvent) async {
        guard isEnabled else { return }
        do {
            switch event {
            case .stateUpdate(let data):
                try await store.setState(.engineState, data)
            case .accountChange(let change):
                await handleAccountChange(change)
            case .fetched(let saves, let deletes):
                eventCount += 1
                try await received(SyncInboundBatch(saves: saves, deletes: deletes))
            case .sent(let saved, let deleted, let failed):
                eventCount += 1
                try await handleSent(saved: saved, deleted: deleted, failed: failed)
            case .zoneDeleted:
                eventCount += 1
                guard !isResettingZone else { return }
                await disable(notice: "The iCloud data of Timelane was removed (on another device or in iCloud settings). "
                    + "Sync was turned off; your data on this device is kept.")
            }
        } catch {
            report(error)
        }
    }

    private func handleAccountChange(_ change: SyncAccountChange) async {
        switch change {
        case .signIn: break
        case .signOut:
            await disable(notice: "You signed out of iCloud, so sync was turned off. Your data on this device is kept.")
        case .switchAccounts:
            await disable(notice: "The iCloud account changed, so sync was turned off. Your data on this device is kept; "
                + "turn sync on again to choose what to do with it.")
        }
    }

    private func received(_ batch: SyncInboundBatch) async throws {
        let result = try await store.applyInbound(batch)
        await finishApply(result)
    }

    private func finishApply(_ result: SyncApplyResult) async {
        await markSynced()
        if !result.changedEntryIds.isEmpty { onRemoteEntryChanges(result.changedEntryIds) }
        if !result.clearedCustomIdProjects.isEmpty {
            let names = result.clearedCustomIdProjects.joined(separator: ", ")
            customIdNotice = "Another project already used the same ID, so these projects lost theirs: \(names)."
        }
        hasRecordsFromNewerApp = result.hasRecordsFromNewerApp
        if !result.requeue.isEmpty { await engine.addPendingSaves(result.requeue) }
    }

    private func handleSent(saved: [SyncServerRecord], deleted: [SyncRecordID], failed: [SyncFailedSend]) async throws {
        if !saved.isEmpty || !deleted.isEmpty { await markSynced() }
        var again: [SyncRecordID] = []
        for record in saved {
            if try await store.markSent(record) { again.append(record.record.id) }
        }
        for id in deleted {
            if try await store.markDeleted(id) { again.append(id) }
        }
        for item in failed { try await handleFailure(item, again: &again) }
        if !again.isEmpty { await engine.addPendingSaves(again) }
    }

    private func handleFailure(_ item: SyncFailedSend, again: inout [SyncRecordID]) async throws {
        switch item.failure {
        case .serverRecordChanged(let server, let systemFields):
            if item.isDelete {
                await engine.addPendingDeletes([item.id])
                return
            }
            // Merge with the server's version (B1/D3); the result is sent again if it still differs.
            let batch = SyncInboundBatch(saves: [SyncServerRecord(record: server, systemFields: systemFields)])
            let result = try await store.applyInbound(batch)
            await finishApply(result)
        case .unknownItem:
            if item.isDelete {
                // Deleted on both devices (B4): the goal is reached.
                if try await store.markDeleted(item.id) { again.append(item.id) }
            } else {
                // Someone deleted it meanwhile: forget the stale change tag, look at the server again, then send.
                try await store.clearSystemFields(for: item.id)
                again.append(item.id)
                scheduleSync()
            }
        case .zoneNotFound:
            zoneResetPending = true
            scheduleSync()
        case .quotaExceeded:
            pauseReason = "iCloud storage is full"
        case .networkUnavailable:
            pauseReason = "Waiting for network"
        case .other(let message):
            errorMessage = message
        }
    }
}
