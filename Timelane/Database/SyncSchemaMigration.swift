import Foundation
import GRDB

/// Schema v5: global sync identities, change timestamps, sync bookkeeping tables and the triggers that
/// record every local change in `syncOutbox`.
enum SyncSchemaMigration {
    static func apply(_ db: Database) throws {
        try addColumnsAndBackfill(db)
        try createTables(db)
        // Triggers come last so the backfill above does not queue the whole database.
        try createTriggers(db, table: "project", recordType: "Project")
        try createTriggers(db, table: "timeEntry", recordType: "TimeEntry")
    }

    private static func addColumnsAndBackfill(_ db: Database) throws {
        try db.alter(table: "project") { t in
            t.add(column: "syncId", .text)
            t.add(column: "updatedAt", .double).notNull().defaults(to: 0)
        }
        try db.alter(table: "timeEntry") { t in
            t.add(column: "syncId", .text)
            t.add(column: "timesUpdatedAt", .double).notNull().defaults(to: 0)
            t.add(column: "textUpdatedAt", .double).notNull().defaults(to: 0)
            t.add(column: "projectUpdatedAt", .double).notNull().defaults(to: 0)
        }
        try db.execute(sql: "UPDATE project SET updatedAt = createdAt")
        try db.execute(sql: "UPDATE timeEntry SET timesUpdatedAt = updatedAt, textUpdatedAt = updatedAt, projectUpdatedAt = updatedAt")
        for table in ["project", "timeEntry"] {
            for id in try Int64.fetchAll(db, sql: "SELECT id FROM \(table)") {
                try db.execute(sql: "UPDATE \(table) SET syncId = ? WHERE id = ?", arguments: [UUID().uuidString, id])
            }
        }
        try db.execute(sql: "CREATE UNIQUE INDEX project_syncId ON project(syncId)")
        try db.execute(sql: "CREATE UNIQUE INDEX timeEntry_syncId ON timeEntry(syncId)")
    }

    private static func createTables(_ db: Database) throws {
        try db.execute(sql: """
            CREATE TABLE syncState (key TEXT PRIMARY KEY NOT NULL, value BLOB);
            CREATE TABLE syncRecordMeta (
                recordType TEXT NOT NULL, syncId TEXT NOT NULL, systemFields BLOB,
                PRIMARY KEY (recordType, syncId));
            CREATE TABLE syncOutbox (
                recordType TEXT NOT NULL, syncId TEXT NOT NULL,
                kind TEXT NOT NULL CHECK (kind IN ('save', 'delete')), queuedAt DOUBLE NOT NULL,
                PRIMARY KEY (recordType, syncId));
            CREATE TABLE syncParkedRecord (
                recordType TEXT NOT NULL, syncId TEXT NOT NULL, payload BLOB NOT NULL,
                reason TEXT, receivedAt DOUBLE NOT NULL,
                PRIMARY KEY (recordType, syncId));
            CREATE TABLE syncTombstone (
                recordType TEXT NOT NULL, syncId TEXT NOT NULL, payload BLOB NOT NULL, deletedAt DOUBLE NOT NULL,
                PRIMARY KEY (recordType, syncId));
            CREATE TABLE syncApplyingRemote (marker INTEGER PRIMARY KEY NOT NULL);
            """)
    }

    private static func createTriggers(_ db: Database, table: String, recordType: String) throws {
        let guardClause = "WHEN NOT EXISTS (SELECT 1 FROM syncApplyingRemote)"
        let now = "(julianday('now') - 2440587.5) * 86400.0"
        func body(_ kind: String, _ row: String) -> String {
            """
            BEGIN
                INSERT OR REPLACE INTO syncOutbox (recordType, syncId, kind, queuedAt)
                VALUES ('\(recordType)', \(row).syncId, '\(kind)', \(now));
            END
            """
        }
        try db.execute(sql: "CREATE TRIGGER \(table)_sync_insert AFTER INSERT ON \(table) \(guardClause) \(body("save", "NEW"))")
        try db.execute(sql: "CREATE TRIGGER \(table)_sync_update AFTER UPDATE ON \(table) \(guardClause) \(body("save", "NEW"))")
        try db.execute(sql: "CREATE TRIGGER \(table)_sync_delete AFTER DELETE ON \(table) \(guardClause) \(body("delete", "OLD"))")
    }
}
