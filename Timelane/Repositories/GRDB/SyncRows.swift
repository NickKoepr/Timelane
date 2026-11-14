import Foundation
import GRDB

/// Row-level reads and writes for the sync layer. All SQL of `GRDBSyncStore` lives here and in the
/// inbound applier; `syncId` columns are compared as uppercase text (`UUID.uuidString`).
enum SyncRows {
    // MARK: Projects and entries

    static func project(_ db: Database, syncId: UUID) throws -> Project? {
        try Project.fetchOne(db, sql: "SELECT * FROM project WHERE syncId = ?", arguments: [syncId.uuidString])
    }

    static func projectId(_ db: Database, syncId: UUID) throws -> Int64? {
        try Int64.fetchOne(db, sql: "SELECT id FROM project WHERE syncId = ?", arguments: [syncId.uuidString])
    }

    static func projectSyncId(_ db: Database, id: Int64) throws -> UUID? {
        let text = try String.fetchOne(db, sql: "SELECT syncId FROM project WHERE id = ?", arguments: [id])
        return text.flatMap { UUID(uuidString: $0) }
    }

    static func entryRow(_ db: Database, syncId: UUID) throws -> SyncTimeEntryRow? {
        try SyncTimeEntryRow.fetchOne(db, sql: "SELECT * FROM timeEntry WHERE syncId = ?", arguments: [syncId.uuidString])
    }

    static func entryFields(_ db: Database, row: SyncTimeEntryRow) throws -> TimeEntryFields? {
        guard let projectSyncId = try projectSyncId(db, id: row.entry.projectId) else { return nil }
        return SyncRecordMapping.fields(for: row, projectSyncId: projectSyncId)
    }

    /// The current local version of a record, if the row exists.
    static func record(_ db: Database, id: SyncRecordID) throws -> SyncRecord? {
        switch id.recordType {
        case .project:
            return try project(db, syncId: id.syncId).map {
                SyncRecord(syncId: id.syncId, project: SyncRecordMapping.fields(for: $0))
            }
        case .timeEntry:
            guard let row = try entryRow(db, syncId: id.syncId),
                  let fields = try entryFields(db, row: row) else { return nil }
            return SyncRecord(syncId: id.syncId, timeEntry: fields)
        }
    }

    /// Inserts or updates the entry and sets its three group timestamps exactly (bypassing the repository's stamping).
    @discardableResult
    static func writeEntry(_ db: Database, row: SyncTimeEntryRow) throws -> Int64 {
        var entry = row.entry
        try entry.save(db)
        guard let id = entry.id else { throw RepositoryError.invalidRange }
        try db.execute(sql: """
            UPDATE timeEntry SET timesUpdatedAt = ?, textUpdatedAt = ?, projectUpdatedAt = ? WHERE id = ?
            """, arguments: [row.timesUpdatedAt.timeIntervalSince1970, row.textUpdatedAt.timeIntervalSince1970,
                             row.projectUpdatedAt.timeIntervalSince1970, id])
        return id
    }

    // MARK: Outbox

    static func outbox(_ db: Database) throws -> [SyncOutboxItem] {
        let rows = try Row.fetchAll(db, sql: "SELECT recordType, syncId, kind FROM syncOutbox ORDER BY queuedAt, rowid")
        return rows.compactMap { row -> SyncOutboxItem? in
            guard let type = SyncRecordType(rawValue: row["recordType"]), let syncId = UUID(uuidString: row["syncId"]),
                  let kind = SyncOutboxItem.Kind(rawValue: row["kind"]) else { return nil }
            return SyncOutboxItem(id: SyncRecordID(recordType: type, syncId: syncId), kind: kind)
        }
    }

    static func outboxKind(_ db: Database, _ id: SyncRecordID) throws -> SyncOutboxItem.Kind? {
        let text = try String.fetchOne(db, sql: "SELECT kind FROM syncOutbox WHERE recordType = ? AND syncId = ?",
                                       arguments: [id.recordType.rawValue, id.recordName])
        return text.flatMap { SyncOutboxItem.Kind(rawValue: $0) }
    }

    static func queueSave(_ db: Database, _ id: SyncRecordID) throws {
        try db.execute(sql: "INSERT OR REPLACE INTO syncOutbox (recordType, syncId, kind, queuedAt) VALUES (?, ?, 'save', ?)",
                       arguments: [id.recordType.rawValue, id.recordName, Date.now.timeIntervalSince1970])
    }

    static func removeOutbox(_ db: Database, _ id: SyncRecordID, kind: SyncOutboxItem.Kind? = nil) throws {
        try db.execute(sql: "DELETE FROM syncOutbox WHERE recordType = ? AND syncId = ? AND (? IS NULL OR kind = ?)",
                       arguments: [id.recordType.rawValue, id.recordName, kind?.rawValue, kind?.rawValue])
    }

    // MARK: System fields

    static func systemFields(_ db: Database, _ id: SyncRecordID) throws -> Data? {
        try Data.fetchOne(db, sql: "SELECT systemFields FROM syncRecordMeta WHERE recordType = ? AND syncId = ?",
                          arguments: [id.recordType.rawValue, id.recordName])
    }

    static func setSystemFields(_ db: Database, _ id: SyncRecordID, _ data: Data?) throws {
        guard let data else {
            try db.execute(sql: "DELETE FROM syncRecordMeta WHERE recordType = ? AND syncId = ?",
                           arguments: [id.recordType.rawValue, id.recordName])
            return
        }
        try db.execute(sql: "INSERT OR REPLACE INTO syncRecordMeta (recordType, syncId, systemFields) VALUES (?, ?, ?)",
                       arguments: [id.recordType.rawValue, id.recordName, data])
    }
}
