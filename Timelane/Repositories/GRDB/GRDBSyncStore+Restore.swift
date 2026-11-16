import Foundation
import GRDB

extension GRDBSyncStore {
    func restoreSyncedData(from file: URL, uploadPending: Bool) async throws {
        try await database.writer.write { db in
            let backup = try Self.readBackup(file)      // read here: GRDB rows are not Sendable
            let links = try Self.trackedAppLinks(db)
            try db.execute(sql: "INSERT OR REPLACE INTO syncApplyingRemote (marker) VALUES (1)")
            try db.execute(sql: "DELETE FROM timeEntry")
            try db.execute(sql: "DELETE FROM project")
            var projectIds: [Int64: Int64] = [:]
            for row in backup.projects {
                try Self.insert(row, into: "project", db: db)
                if let old: Int64 = row["id"] { projectIds[old] = db.lastInsertedRowID }
            }
            for row in backup.entries {
                guard let old: Int64 = row["projectId"], let projectId = projectIds[old] else { continue }
                try Self.insert(row, into: "timeEntry", db: db, overriding: ["projectId": projectId])
            }
            try db.execute(sql: "DELETE FROM syncApplyingRemote")
            for table in ["syncOutbox", "syncParkedRecord", "syncTombstone", "syncRecordMeta"] {
                try db.execute(sql: "DELETE FROM \(table)")
            }
            try db.execute(sql: "DELETE FROM syncState WHERE key <> ?", arguments: [SyncStateKey.enabled.rawValue])
            if uploadPending {
                try db.execute(sql: "INSERT OR REPLACE INTO syncState (key, value) VALUES (?, ?)",
                               arguments: [SyncStateKey.restoreUploadPending.rawValue, Data([1])])
            }
            try Self.relink(db, links)
        }
    }

    private static func readBackup(_ file: URL) throws -> (projects: [Row], entries: [Row]) {
        let queue = try DatabaseQueue(path: file.path)
        return try queue.read { db in
            (try Row.fetchAll(db, sql: "SELECT * FROM project ORDER BY id"),
             try Row.fetchAll(db, sql: "SELECT * FROM timeEntry ORDER BY id"))
        }
    }

    /// Inserts a row read from a database with the same schema, without its `id` (a new one is assigned).
    private static func insert(_ row: Row, into table: String, db: Database,
                               overriding overrides: [String: any DatabaseValueConvertible] = [:]) throws {
        let columns = row.columnNames.filter { $0 != "id" }
        let values: [DatabaseValue] = columns.map { column in
            overrides[column]?.databaseValue ?? row[column] as DatabaseValue
        }
        let list = columns.map { "\"\($0)\"" }.joined(separator: ", ")
        let marks = Array(repeating: "?", count: columns.count).joined(separator: ", ")
        try db.execute(sql: "INSERT INTO \(table) (\(list)) VALUES (\(marks))", arguments: StatementArguments(values))
    }
}
