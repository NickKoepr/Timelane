import Foundation
import GRDB

extension GRDBSyncStore {
    func allRecords() async throws -> [SyncRecord] {
        try await database.writer.read { db in
            var records: [SyncRecord] = []
            for project in try Project.order(Column("id")).fetchAll(db) {
                records.append(SyncRecord(syncId: project.syncId, project: SyncRecordMapping.fields(for: project)))
            }
            for row in try SyncTimeEntryRow.fetchAll(db, sql: "SELECT * FROM timeEntry ORDER BY id") {
                if let fields = try SyncRows.entryFields(db, row: row) {
                    records.append(SyncRecord(syncId: row.entry.syncId, timeEntry: fields))
                }
            }
            return records
        }
    }

    func hasSyncedData() async throws -> Bool {
        try await database.writer.read { db in
            try Int.fetchOne(db, sql: "SELECT (SELECT COUNT(*) FROM project) + (SELECT COUNT(*) FROM timeEntry)") ?? 0 > 0
        }
    }

    func parkedRecords() async throws -> [SyncParkedRecord] {
        try await database.writer.read { db in try SyncRows.parked(db) }
    }

    func wipeSyncMetadata() async throws {
        try await database.writer.write { db in
            for table in ["syncState", "syncRecordMeta", "syncOutbox", "syncParkedRecord", "syncTombstone"] {
                try db.execute(sql: "DELETE FROM \(table)")
            }
        }
    }

    func wipeLocalSyncedData() async throws -> [SyncTrackedAppLink] {
        try await database.writer.write { db in
            let links = try Self.trackedAppLinks(db)
            // The marker keeps the deletes out of the outbox: replacing this device must not delete anything in iCloud.
            try Self.deleteSyncedRowsSilently(db)
            for table in ["syncOutbox", "syncParkedRecord", "syncTombstone", "syncRecordMeta"] {
                try db.execute(sql: "DELETE FROM \(table)")
            }
            return links
        }
    }

    func relinkTrackedApps(_ links: [SyncTrackedAppLink]) async throws {
        try await database.writer.write { db in try Self.relink(db, links) }
    }

    // MARK: Shared steps (also used by restoring a backup)

    static func trackedAppLinks(_ db: Database) throws -> [SyncTrackedAppLink] {
        let rows = try Row.fetchAll(db, sql: """
            SELECT trackedApp.bundleIdentifier AS bundle, project.name AS name
            FROM trackedApp JOIN project ON project.id = trackedApp.projectId
            """)
        return rows.map { row in SyncTrackedAppLink(bundleIdentifier: row["bundle"], projectName: row["name"]) }
    }

    /// Deletes every time entry and project without queueing deletes for iCloud.
    static func deleteSyncedRowsSilently(_ db: Database) throws {
        try db.execute(sql: "INSERT OR REPLACE INTO syncApplyingRemote (marker) VALUES (1)")
        try db.execute(sql: "DELETE FROM timeEntry")
        try db.execute(sql: "DELETE FROM project")
        try db.execute(sql: "DELETE FROM syncApplyingRemote")
    }

    static func relink(_ db: Database, _ links: [SyncTrackedAppLink]) throws {
        for link in links {
            try db.execute(sql: """
                UPDATE trackedApp SET projectId = (SELECT id FROM project WHERE name = ? COLLATE NOCASE)
                WHERE bundleIdentifier = ?
                """, arguments: [link.projectName, link.bundleIdentifier])
        }
    }
}
