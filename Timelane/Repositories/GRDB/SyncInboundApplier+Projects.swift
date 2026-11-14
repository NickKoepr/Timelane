import Foundation
import GRDB

extension SyncInboundApplier {
    func applyProject(_ syncId: UUID, _ remote: ProjectFields) throws {
        let id = SyncRecordID(recordType: .project, syncId: syncId)
        let local = try SyncRows.project(db, syncId: syncId)
        let localFields = local.map(SyncRecordMapping.fields(for:))
        let merged = SyncMergePolicy.merge(local: localFields, remote: remote)
        if local == nil || merged != localFields {
            try writeProject(syncId: syncId, localId: local?.id, fields: merged)
        }
        try reconcileOutbox(id, merged: .project(merged), remote: .project(remote))
    }

    /// Writes the project. A name or customer id that another project already has (the table keeps them
    /// unique) is stored under a placeholder; `overrides` remembers the real values for the conflict resolver.
    func writeProject(syncId: UUID, localId: Int64?, fields: ProjectFields) throws {
        var project = SyncRecordMapping.project(from: fields, syncId: syncId, localId: localId)
        var placeholder = false
        let nameClashes = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM project WHERE name = ? COLLATE NOCASE AND syncId != ?",
                                           arguments: [fields.name, syncId.uuidString]) ?? 0
        if nameClashes > 0 {
            project.name = "\(fields.name) \u{200B}\(syncId.uuidString)"
            placeholder = true
        }
        if let customId = fields.customId {
            let idClashes = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM project WHERE customId = ? COLLATE NOCASE AND syncId != ?",
                                             arguments: [customId, syncId.uuidString]) ?? 0
            if idClashes > 0 {
                project.customId = nil
                placeholder = true
            }
        }
        overrides[syncId] = placeholder ? fields : nil
        try project.save(db)
    }

    func applyDelete(_ id: SyncRecordID) throws {
        try SyncRows.setSystemFields(db, id, nil)
        try SyncRows.unpark(db, id)
        switch id.recordType {
        case .timeEntry: try deleteEntry(id)
        case .project: try deleteProject(id)
        }
    }

    private func deleteProject(_ id: SyncRecordID) throws {
        let local = try SyncRows.project(db, syncId: id.syncId)
        var dependents = 0
        if let localId = local?.id {
            dependents = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM timeEntry WHERE projectId = ?", arguments: [localId]) ?? 0
        }
        switch SyncDeleteDecision.forRemoteDelete(recordType: .project, existsLocally: local != nil, dependentEntryCount: dependents) {
        case .alreadyGone:
            try SyncRows.removeOutbox(db, id)
            try SyncRows.removeTombstone(db, id)
        case .deleteLocal:
            try db.execute(sql: "DELETE FROM project WHERE syncId = ?", arguments: [id.recordName])
            try SyncRows.removeOutbox(db, id)
            overrides[id.syncId] = nil
        case .resurrect:
            // An entry still uses the project: keep it and upload it again as a new record (C4).
            resurrected.append(id.syncId)
        }
    }

    /// Re-creates a locally deleted project from its tombstone because a remote entry refers to it (C4).
    func resurrectFromTombstone(_ syncId: UUID) throws -> Int64? {
        guard let fields = try SyncRows.tombstone(db, projectSyncId: syncId) else { return nil }
        try writeProject(syncId: syncId, localId: nil, fields: fields)
        try SyncRows.removeTombstone(db, SyncRecordID(recordType: .project, syncId: syncId))
        resurrected.append(syncId)
        return try SyncRows.projectId(db, syncId: syncId)
    }
}
