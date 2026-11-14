import Foundation
import GRDB

/// Makes a consistent copy of the live database (online backup API), keeps only the tables of one backup part,
/// and describes it. Sync bookkeeping is never part of a backup.
struct BackupSnapshotter: Sendable {
    let database: AppDatabase

    static let syncTables = ["syncState", "syncRecordMeta", "syncOutbox", "syncParkedRecord", "syncTombstone",
                             "syncApplyingRemote"]

    func makeSnapshot(_ part: BackupPart, in directory: URL, deviceName: String, appVersion: String,
                      now: Date = .now) throws -> (file: URL, info: BackupInfo) {
        precondition(part != .legacy, "Legacy backups are never written")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("snapshot.sqlite")
        try? FileManager.default.removeItem(at: file)
        // The destination queue is closed again before the file is handed out.
        let info: BackupInfo
        do {
            let destination = try DatabaseQueue(path: file.path)
            try database.writer.backup(to: destination)
            try destination.write { db in try Self.strip(db, to: part) }
            try destination.vacuum()
            let migrator = Migrations.makeMigrator()
            info = try destination.read { db -> BackupInfo in
                let applied = try migrator.appliedIdentifiers(db)
                return BackupInfo(
                    createdAt: now, deviceName: deviceName, appVersion: appVersion,
                    schemaVersion: migrator.migrations.last(where: applied.contains) ?? "",
                    projectCount: try Project.fetchCount(db), timeEntryCount: try TimeEntry.fetchCount(db))
            }
        }
        return (file, info)
    }

    /// Copies the whole live database to `file` (the safety copy kept before a restore).
    func copyWholeDatabase(to file: URL) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: file.path + suffix) }
        let destination = try DatabaseQueue(path: file.path)
        try database.writer.backup(to: destination)
    }

    private static func strip(_ db: Database, to part: BackupPart) throws {
        switch part {
        case .projectsAndHours:
            try db.execute(sql: "DELETE FROM appSession")
            try db.execute(sql: "DELETE FROM trackedApp")
        case .appActivity:
            // Projects stay so tracked apps keep their links (by name); the hours are in the other part.
            try db.execute(sql: "DELETE FROM timeEntry")
        case .legacy:
            break
        }
        // Last: deleting rows above fills the outbox through the sync triggers.
        for table in syncTables { try db.execute(sql: "DELETE FROM \(table)") }
    }
}
