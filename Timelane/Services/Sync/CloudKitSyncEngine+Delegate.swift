import CloudKit
import Foundation

extension CloudKitSyncEngine {
    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        // An engine that was replaced (zone reset) may still deliver events; they belong to the old state.
        guard let handler = locked({ storage in storage.engine === syncEngine ? storage.handler : nil }) else { return }
        for translated in translate(event) { await handler(translated) }
    }

    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async
        -> CKSyncEngine.RecordZoneChangeBatch? {
        let scope = context.options.scope
        let pending = syncEngine.state.pendingRecordZoneChanges.filter { scope.contains($0) }
        guard !pending.isEmpty, let provider = locked({ $0.provider }) else { return nil }

        var records: [CKRecord.ID: CKRecord] = [:]
        var batch: [CKSyncEngine.PendingRecordZoneChange] = []
        var stale: [CKSyncEngine.PendingRecordZoneChange] = []
        for change in pending {
            guard case .saveRecord(let recordID) = change else {
                batch.append(change)
                continue
            }
            if let upload = await Self.upload(for: recordID, provider: provider) {
                records[recordID] = Self.makeRecord(from: upload)
                locked { $0.inFlight[recordID] = upload.record }
                batch.append(change)
            } else {
                stale.append(change)     // the row is gone or already sent: nothing to upload
            }
        }
        if !stale.isEmpty { syncEngine.state.remove(pendingRecordZoneChanges: stale) }
        guard !batch.isEmpty else { return nil }
        let box = RecordBox(records)
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: batch) { recordID in box.records[recordID] }
    }

    /// A record name does not say which table it belongs to; syncIds are unique across both, so try each.
    private static func upload(for recordID: CKRecord.ID, provider: Provider) async -> SyncUploadRecord? {
        guard let syncId = UUID(uuidString: recordID.recordName) else { return nil }
        for type in SyncRecordType.allCases {
            if let upload = await provider(SyncRecordID(recordType: type, syncId: syncId)) { return upload }
        }
        return nil
    }
}

/// `CKRecord` is not `Sendable`; the batch is built and consumed by the engine only.
private final class RecordBox: @unchecked Sendable {
    let records: [CKRecord.ID: CKRecord]
    init(_ records: [CKRecord.ID: CKRecord]) { self.records = records }
}
