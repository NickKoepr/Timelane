import Foundation
import GRDB

/// Adds the app activity of a backup file to the live database without removing anything: sessions that overlap
/// no local session of the same app, and tracked apps that are not on the list yet (linked to a project by name).
struct ActivityBackupMerger: Sendable {
    let database: AppDatabase

    struct Result: Equatable, Sendable {
        var sessions = 0
        var trackedApps = 0
    }

    @discardableResult
    func merge(from file: URL) throws -> Result {
        let queue = try DatabaseQueue(path: file.path)
        let (sessions, apps) = try queue.read { db in
            (try Row.fetchAll(db, sql: "SELECT bundleIdentifier, appName, start, \"end\" FROM appSession ORDER BY start"),
             try Row.fetchAll(db, sql: """
                SELECT trackedApp.bundleIdentifier, trackedApp.name, trackedApp.addedAt, project.name AS projectName
                FROM trackedApp LEFT JOIN project ON project.id = trackedApp.projectId
                """))
        }
        return try database.writer.write { db in
            var result = Result()
            for row in sessions where try Self.addSession(row, db) { result.sessions += 1 }
            for row in apps where try Self.addTrackedApp(row, db) { result.trackedApps += 1 }
            return result
        }
    }

    /// Whether a backup file holds any app sessions (used to decide if an older version's backup may go).
    static func containsActivity(_ file: URL) throws -> Bool {
        let queue = try DatabaseQueue(path: file.path)
        return try queue.read { db in
            try db.tableExists("appSession") && (try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM appSession") ?? 0) > 0
        }
    }

    private static func addSession(_ row: Row, _ db: Database) throws -> Bool {
        let bundle: String = row["bundleIdentifier"]
        let start: Double = row["start"]
        // A session that was still open when the backup was made has no end; keep it as a zero-length one.
        let end: Double = row["end"] ?? start
        let overlaps = try Bool.fetchOne(db, sql: """
            SELECT EXISTS (SELECT 1 FROM appSession WHERE bundleIdentifier = ?
                AND (start = ? OR (start < ? AND COALESCE("end", start) > ?)))
            """, arguments: [bundle, start, end, start]) ?? false
        guard !overlaps else { return false }
        try db.execute(sql: "INSERT INTO appSession (bundleIdentifier, appName, start, \"end\") VALUES (?, ?, ?, ?)",
                       arguments: [bundle, row["appName"] as String, start, end])
        return true
    }

    private static func addTrackedApp(_ row: Row, _ db: Database) throws -> Bool {
        let bundle: String = row["bundleIdentifier"]
        let exists = try Bool.fetchOne(db, sql: "SELECT EXISTS (SELECT 1 FROM trackedApp WHERE bundleIdentifier = ?)",
                                       arguments: [bundle]) ?? false
        guard !exists else { return false }
        let projectName: String? = row["projectName"]
        try db.execute(sql: """
            INSERT INTO trackedApp (bundleIdentifier, name, addedAt, projectId)
            VALUES (?, ?, ?, (SELECT id FROM project WHERE name = ? COLLATE NOCASE))
            """, arguments: [bundle, row["name"] as String, row["addedAt"] as Double, projectName])
        return true
    }
}
