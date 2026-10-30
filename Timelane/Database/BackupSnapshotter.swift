import Foundation
import GRDB

/// Makes a consistent copy of the live database (online backup API) and describes it.
struct BackupSnapshotter: Sendable {
    let database: AppDatabase

    func makeSnapshot(in directory: URL, deviceName: String, appVersion: String,
                      now: Date = .now) throws -> (file: URL, info: BackupInfo) {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("snapshot.sqlite")
        try? FileManager.default.removeItem(at: file)
        // The destination queue is closed again before the file is handed out.
        do {
            let destination = try DatabaseQueue(path: file.path)
            try database.writer.backup(to: destination)
        }
        let migrator = Migrations.makeMigrator()
        let info = try database.writer.read { db -> BackupInfo in
            let applied = try migrator.appliedIdentifiers(db)
            return BackupInfo(
                createdAt: now, deviceName: deviceName, appVersion: appVersion,
                schemaVersion: migrator.migrations.last(where: applied.contains) ?? "",
                projectCount: try Project.fetchCount(db), timeEntryCount: try TimeEntry.fetchCount(db))
        }
        return (file, info)
    }
}
