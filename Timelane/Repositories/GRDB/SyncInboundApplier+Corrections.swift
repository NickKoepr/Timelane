import Foundation
import GRDB

/// The part of an inbound batch that runs without the marker: its writes are local changes and are uploaded.
extension SyncInboundApplier {
    func applyCorrections() throws {
        for syncId in resurrected {
            try SyncRows.queueSave(db, SyncRecordID(recordType: .project, syncId: syncId))
        }
        if !overrides.isEmpty { try resolveProjectConflicts() }
        try settleOverlaps()
    }

    // MARK: Projects (C1-C3)

    private func resolveProjectConflicts() throws {
        let snapshots = try Project.fetchAll(db).map { project in
            SyncProjectSnapshot(localId: project.id, syncId: project.syncId,
                                fields: overrides[project.syncId] ?? SyncRecordMapping.fields(for: project))
        }
        let plan = ProjectConflictResolver.resolve(snapshots)

        for merge in plan.merges {
            guard let loser = try SyncRows.projectId(db, syncId: merge.loser),
                  let survivor = try SyncRows.projectId(db, syncId: merge.survivor) else { continue }
            let moved = try Int64.fetchAll(db, sql: "SELECT id FROM timeEntry WHERE projectId = ?", arguments: [loser])
            try db.execute(sql: "UPDATE timeEntry SET projectId = ? WHERE projectId = ?", arguments: [survivor, loser])
            try db.execute(sql: "UPDATE trackedApp SET projectId = ? WHERE projectId = ?", arguments: [survivor, loser])
            try db.execute(sql: "DELETE FROM project WHERE id = ?", arguments: [loser])
            changedEntryIds.formUnion(moved)
            overrides[merge.loser] = nil
        }
        for rename in plan.renames {
            overrides[rename.syncId]?.name = rename.newName
            try db.execute(sql: "UPDATE project SET name = ? WHERE syncId = ?", arguments: [rename.newName, rename.syncId.uuidString])
            try SyncRows.queueSave(db, SyncRecordID(recordType: .project, syncId: rename.syncId))
        }
        for syncId in plan.clearedCustomIds {
            overrides[syncId]?.customId = nil
            if let name = try String.fetchOne(db, sql: "SELECT name FROM project WHERE syncId = ?", arguments: [syncId.uuidString]) {
                clearedCustomIdProjects.append(overrides[syncId]?.name ?? name)
            }
            try db.execute(sql: "UPDATE project SET customId = NULL WHERE syncId = ?", arguments: [syncId.uuidString])
            try SyncRows.queueSave(db, SyncRecordID(recordType: .project, syncId: syncId))
        }
        try restorePlaceholders()
    }

    /// Gives the projects stored under a placeholder their real name and customer id, silently (the
    /// outbox already holds whatever the plan changed, and the rest equals the server).
    private func restorePlaceholders() throws {
        try db.execute(sql: "INSERT OR REPLACE INTO syncApplyingRemote (marker) VALUES (1)")
        for (syncId, fields) in overrides.sorted(by: { $0.key.uuidString < $1.key.uuidString }) {
            try db.execute(sql: "UPDATE project SET name = ?, customId = ? WHERE syncId = ?",
                           arguments: [fields.name, fields.customId, syncId.uuidString])
        }
        try db.execute(sql: "DELETE FROM syncApplyingRemote")
        overrides = [:]
    }

    // MARK: Overlaps (D1)

    private func settleOverlaps() throws {
        guard let from = touched.map(\.start).min(), let until = touched.map(\.end).max() else { return }
        let rows = try SyncTimeEntryRow.fetchAll(db, sql: "SELECT * FROM timeEntry WHERE start < ? AND \"end\" > ?",
                                                 arguments: [until.timeIntervalSince1970, from.timeIntervalSince1970])
        let entries = try rows.compactMap { row -> SyncSettlerEntry? in
            try SyncRows.entryFields(db, row: row).map { SyncSettlerEntry(syncId: row.entry.syncId, fields: $0) }
        }
        let settlement = TimeEntrySettler.settle(entries)
        for syncId in settlement.deletes {
            if let row = try SyncRows.entryRow(db, syncId: syncId), let id = row.entry.id {
                try db.execute(sql: "DELETE FROM timeEntry WHERE id = ?", arguments: [id])
                changedEntryIds.insert(id)
            }
        }
        for save in settlement.saves {
            let existing = try SyncRows.entryRow(db, syncId: save.syncId)
            guard let row = SyncRecordMapping.row(from: save.fields, syncId: save.syncId, localId: existing?.entry.id,
                                                  projectId: { try? SyncRows.projectId(db, syncId: $0) }) else { continue }
            let id = try SyncRows.writeEntry(db, row: row)
            if existing != nil { changedEntryIds.insert(id) }
        }
    }
}
