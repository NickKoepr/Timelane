import Foundation
import GRDB

/// Parked records (arrived before their project, or from a newer app) and project tombstones.
extension SyncRows {
    static func park(_ db: Database, _ record: SyncRecord, reason: String) throws {
        let payload = try JSONEncoder().encode(record)
        try db.execute(sql: """
            INSERT OR REPLACE INTO syncParkedRecord (recordType, syncId, payload, reason, receivedAt) VALUES (?, ?, ?, ?, ?)
            """, arguments: [record.recordType.rawValue, record.syncId.uuidString, payload, reason, Date.now.timeIntervalSince1970])
    }

    static func unpark(_ db: Database, _ id: SyncRecordID) throws {
        try db.execute(sql: "DELETE FROM syncParkedRecord WHERE recordType = ? AND syncId = ?",
                       arguments: [id.recordType.rawValue, id.recordName])
    }

    static func parked(_ db: Database) throws -> [SyncParkedRecord] {
        let rows = try Row.fetchAll(db, sql: "SELECT payload, reason FROM syncParkedRecord ORDER BY receivedAt, rowid")
        return rows.compactMap { row -> SyncParkedRecord? in
            let payload: Data = row["payload"]
            guard let record = try? JSONDecoder().decode(SyncRecord.self, from: payload) else { return nil }
            let reason: String? = row["reason"]
            return SyncParkedRecord(record: record, reason: reason ?? "")
        }
    }

    // MARK: Tombstones

    /// Keeps the last copy of a project that is being deleted locally, so that an entry another device adds
    /// to it meanwhile can bring it back (C4). Removed once the server confirmed the delete.
    static func writeTombstone(_ db: Database, project: Project) throws {
        let payload = try JSONEncoder().encode(SyncRecordMapping.fields(for: project))
        try db.execute(sql: """
            INSERT OR REPLACE INTO syncTombstone (recordType, syncId, payload, deletedAt) VALUES ('Project', ?, ?, ?)
            """, arguments: [project.syncId.uuidString, payload, Date.now.timeIntervalSince1970])
    }

    static func tombstone(_ db: Database, projectSyncId: UUID) throws -> ProjectFields? {
        let payload = try Data.fetchOne(db, sql: "SELECT payload FROM syncTombstone WHERE recordType = 'Project' AND syncId = ?",
                                        arguments: [projectSyncId.uuidString])
        return payload.flatMap { try? JSONDecoder().decode(ProjectFields.self, from: $0) }
    }

    static func removeTombstone(_ db: Database, _ id: SyncRecordID) throws {
        try db.execute(sql: "DELETE FROM syncTombstone WHERE recordType = ? AND syncId = ?",
                       arguments: [id.recordType.rawValue, id.recordName])
    }
}
