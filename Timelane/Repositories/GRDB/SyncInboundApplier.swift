import Foundation
import GRDB

/// Applies one batch of server changes inside the caller's write transaction.
///
/// While the `syncApplyingRemote` marker row exists, the outbox triggers stay silent, so remote writes are
/// not echoed back. The marker is removed before the corrections (project merges, overlap settling): those
/// writes are real local changes and do enter the outbox. Both devices compute the same corrections from
/// the same rows, so what they upload is identical and a second round has nothing left to send.
///
/// Order: projects, entries, entry deletes, project deletes (so a project delete sees the entries that
/// are still there), then parked records are retried.
final class SyncInboundApplier {
    let db: Database
    var changedEntryIds = Set<Int64>()
    /// Time spans of entries written by this batch; the overlap settling looks at these.
    var touched: [(start: Date, end: Date)] = []
    /// Real fields of projects stored under a placeholder name/customId because they clash with another project.
    var overrides: [UUID: ProjectFields] = [:]
    /// Projects brought back (C4): they are re-uploaded once the marker is gone.
    var resurrected: [UUID] = []
    var clearedCustomIdProjects: [String] = []

    init(db: Database) { self.db = db }

    func run(_ batch: SyncInboundBatch) throws -> SyncApplyResult {
        try db.execute(sql: "INSERT OR REPLACE INTO syncApplyingRemote (marker) VALUES (1)")
        for save in batch.saves { try SyncRows.setSystemFields(db, save.record.id, save.systemFields) }

        let saves = batch.saves.map(\.record)
        for record in saves where record.recordType == .project { try apply(record) }
        for record in saves where record.recordType == .timeEntry { try apply(record) }
        for id in batch.deletes where id.recordType == .timeEntry { try applyDelete(id) }
        for id in batch.deletes where id.recordType == .project { try applyDelete(id) }
        try retryParked()

        try db.execute(sql: "DELETE FROM syncApplyingRemote")
        try applyCorrections()

        var result = SyncApplyResult()
        result.changedEntryIds = changedEntryIds
        result.clearedCustomIdProjects = clearedCustomIdProjects
        for record in saves {
            if try SyncRows.outboxKind(db, record.id) == .save { result.requeue.append(record.id) }
        }
        result.hasRecordsFromNewerApp = try SyncRows.parked(db).contains { $0.reason == SyncParkReason.newerApp }
        return result
    }

    private func apply(_ record: SyncRecord) throws {
        guard record.isSupported else {
            try SyncRows.park(db, record, reason: SyncParkReason.newerApp)
            return
        }
        // A delete that is still waiting to be sent wins over an incoming edit (B3).
        let hasPendingDelete = try SyncRows.outboxKind(db, record.id) == .delete
        guard SyncDeleteDecision.forRemoteSave(hasPendingLocalDelete: hasPendingDelete) == .apply else { return }
        switch record.fields {
        case .project(let fields): try applyProject(record.syncId, fields)
        case .timeEntry(let fields): try applyEntry(record, fields)
        }
    }

    /// After a merge, the server only has what the merge result equals: otherwise the record must go up again.
    func reconcileOutbox(_ id: SyncRecordID, merged: SyncFields, remote: SyncFields) throws {
        if merged == remote {
            try SyncRows.removeOutbox(db, id, kind: .save)
        } else {
            try SyncRows.queueSave(db, id)
        }
    }

    private func retryParked() throws {
        for parked in try SyncRows.parked(db) where parked.record.isSupported {
            if case .timeEntry(let fields) = parked.record.fields { try applyEntry(parked.record, fields) }
        }
    }
}
