import CloudKit
import Foundation

/// CloudKit events as plain `SyncEngineEvent`s.
extension CloudKitSyncEngine {
    func translate(_ event: CKSyncEngine.Event) -> [SyncEngineEvent] {
        switch event {
        case .stateUpdate(let update):
            guard let data = try? JSONEncoder().encode(update.stateSerialization) else { return [] }
            return [.stateUpdate(data)]
        case .accountChange(let change):
            switch change.changeType {
            case .signIn: return [.accountChange(.signIn)]
            case .signOut: return [.accountChange(.signOut)]
            case .switchAccounts: return [.accountChange(.switchAccounts)]
            @unknown default: return []
            }
        case .fetchedDatabaseChanges(let changes):
            return changes.deletions.contains { $0.zoneID == Self.zoneID } ? [.zoneDeleted] : []
        case .fetchedRecordZoneChanges(let changes):
            let saves = changes.modifications.compactMap { Self.serverRecord(from: $0.record) }
            let deletes = changes.deletions.compactMap { deletion -> SyncRecordID? in
                guard let type = SyncRecordType(rawValue: deletion.recordType),
                      let syncId = UUID(uuidString: deletion.recordID.recordName) else { return nil }
                return SyncRecordID(recordType: type, syncId: syncId)
            }
            return saves.isEmpty && deletes.isEmpty ? [] : [.fetched(saves: saves, deletes: deletes)]
        case .sentRecordZoneChanges(let sent):
            return translate(sent)
        default:
            return []
        }
    }

    private func translate(_ sent: CKSyncEngine.Event.SentRecordZoneChanges) -> [SyncEngineEvent] {
        var saved: [SyncServerRecord] = []
        var failed: [SyncFailedSend] = []
        for record in sent.savedRecords {
            guard let value = takeInFlight(record.recordID) ?? Self.syncRecord(from: record) else { continue }
            saved.append(SyncServerRecord(record: value, systemFields: Self.encodeSystemFields(record)))
        }
        for failure in sent.failedRecordSaves {
            guard let value = takeInFlight(failure.record.recordID) ?? Self.syncRecord(from: failure.record) else { continue }
            failed.append(SyncFailedSend(id: value.id, isDelete: false, failure: Self.failure(for: failure.error)))
        }
        var deleted: [SyncRecordID] = []
        for recordID in sent.deletedRecordIDs { deleted += deleteIDs(for: recordID) }
        for (recordID, error) in sent.failedRecordDeletes {
            for id in deleteIDs(for: recordID) {
                failed.append(SyncFailedSend(id: id, isDelete: true, failure: Self.failure(for: error)))
            }
        }
        return saved.isEmpty && deleted.isEmpty && failed.isEmpty ? [] : [.sent(saved: saved, deleted: deleted, failed: failed)]
    }

    private func takeInFlight(_ recordID: CKRecord.ID) -> SyncRecord? {
        locked { $0.inFlight.removeValue(forKey: recordID) }
    }

    /// The type of a queued delete, or both types when it is not known (after a relaunch): a wrong guess is harmless.
    private func deleteIDs(for recordID: CKRecord.ID) -> [SyncRecordID] {
        guard let syncId = UUID(uuidString: recordID.recordName) else { return [] }
        let known = locked { $0.deleteTypes.removeValue(forKey: syncId) }
        let types = known.map { [$0] } ?? SyncRecordType.allCases
        return types.map { SyncRecordID(recordType: $0, syncId: syncId) }
    }

    static func failure(for error: CKError) -> SyncSendFailure {
        switch error.code {
        case .serverRecordChanged:
            if let server = error.serverRecord, let value = syncRecord(from: server) {
                return .serverRecordChanged(server: value, systemFields: encodeSystemFields(server))
            }
            return .other(error.localizedDescription)
        case .unknownItem: return .unknownItem
        case .zoneNotFound: return .zoneNotFound
        case .quotaExceeded: return .quotaExceeded
        case .networkUnavailable, .networkFailure: return .networkUnavailable
        default: return .other(error.localizedDescription)
        }
    }

    static func serverRecord(from record: CKRecord) -> SyncServerRecord? {
        guard let value = syncRecord(from: record) else { return nil }
        return SyncServerRecord(record: value, systemFields: encodeSystemFields(record))
    }
}
