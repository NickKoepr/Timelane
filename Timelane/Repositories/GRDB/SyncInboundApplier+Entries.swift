import Foundation
import GRDB

extension SyncInboundApplier {
    func applyEntry(_ record: SyncRecord, _ remote: TimeEntryFields) throws {
        let id = record.id
        if try SyncRows.outboxKind(db, id) == .delete { return }
        let localRow = try SyncRows.entryRow(db, syncId: record.syncId)
        let localFields = try localRow.flatMap { try SyncRows.entryFields(db, row: $0) }

        var merged = SyncMergePolicy.merge(local: localFields, remote: remote)
        // A project that no longer exists locally (merged away): keep the local project group.
        if let localFields, try SyncRows.projectId(db, syncId: merged.projectSyncId) == nil {
            merged.projectSyncId = localFields.projectSyncId
            merged.projectUpdatedAt = localFields.projectUpdatedAt
        }
        guard merged.end > merged.start else {
            try SyncRows.park(db, record, reason: SyncParkReason.invalid)
            return
        }

        var projectId = try SyncRows.projectId(db, syncId: merged.projectSyncId)
        if projectId == nil {
            switch SyncDeleteDecision.forEntryWithMissingProject(
                hasTombstone: try SyncRows.tombstone(db, projectSyncId: merged.projectSyncId) != nil) {
            case .resurrectFromTombstone: projectId = try resurrectFromTombstone(merged.projectSyncId)
            case .park: break
            }
        }
        guard let projectId else {
            try SyncRows.park(db, record, reason: SyncParkReason.missingProject)
            return
        }

        if localFields == nil || merged != localFields {
            guard let row = SyncRecordMapping.row(from: merged, syncId: record.syncId, localId: localRow?.entry.id,
                                                  projectId: { _ in projectId }) else { return }
            let savedId = try SyncRows.writeEntry(db, row: row)
            if localRow != nil { changedEntryIds.insert(savedId) }
            touched.append((merged.start, merged.end))
            if let old = localFields { touched.append((old.start, old.end)) }
        }
        try SyncRows.unpark(db, id)
        try reconcileOutbox(id, merged: .timeEntry(merged), remote: .timeEntry(remote))
    }

    func deleteEntry(_ id: SyncRecordID) throws {
        // Delete wins (B3); a delete on both devices is no conflict (B4).
        if let row = try SyncRows.entryRow(db, syncId: id.syncId), let rowId = row.entry.id {
            try db.execute(sql: "DELETE FROM timeEntry WHERE id = ?", arguments: [rowId])
            changedEntryIds.insert(rowId)
        }
        try SyncRows.removeOutbox(db, id)
    }
}
