import Foundation
import GRDB

/// A downloaded backup waiting to replace the database. The swap happens in `AppDatabase.live()` before
/// the database is opened, so no live connection or observer has to be patched.
struct PendingRestore: Sendable {
    static let pendingName = "pending-restore.sqlite"
    static let previousName = "db-before-restore.sqlite"
    private static let suffixes = ["", "-wal", "-shm"]

    /// The folder that holds `db.sqlite`.
    let directory: URL

    var pendingFile: URL { directory.appendingPathComponent(Self.pendingName) }
    var hasPendingRestore: Bool { FileManager.default.fileExists(atPath: pendingFile.path) }

    /// A restore folder in the temporary directory, for tests and previews.
    static func temporary() -> PendingRestore {
        PendingRestore(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("TimelaneRestore-\(UUID().uuidString)", isDirectory: true))
    }

    /// Validates the downloaded file, upgrades an older schema and moves it to `pending-restore.sqlite`.
    func stage(_ downloaded: URL) throws {
        try validateAndMigrate(downloaded)
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try? fileManager.removeItem(at: pendingFile)
        try fileManager.moveItem(at: downloaded, to: pendingFile)
    }

    /// Copies a pending restore into the database file. The previous database is kept as `db-before-restore.sqlite`.
    /// Returns false when nothing was pending.
    ///
    /// The pages are copied with SQLite's backup API instead of renaming files: another process may still have
    /// `db.sqlite` open (an old instance that is slow to quit, or a second copy of the app), and renaming a file
    /// under an open connection makes every later query of that process fail with a disk I/O error.
    func applyIfPending(databaseFile: URL) throws -> Bool {
        guard hasPendingRestore else { return false }
        let fileManager = FileManager.default
        let previous = databaseFile.deletingLastPathComponent().appendingPathComponent(Self.previousName)
        for suffix in Self.suffixes { try? fileManager.removeItem(atPath: previous.path + suffix) }
        // The queues are closed again before the pending file is removed.
        do {
            let current = try DatabaseQueue(path: databaseFile.path)
            try current.backup(to: try DatabaseQueue(path: previous.path))
            try DatabaseQueue(path: pendingFile.path).backup(to: current)
        }
        for suffix in Self.suffixes { try? fileManager.removeItem(atPath: pendingFile.path + suffix) }
        return true
    }

    private func validateAndMigrate(_ file: URL) throws {
        let migrator = Migrations.makeMigrator()
        do {
            let queue = try DatabaseQueue(path: file.path)
            let isTimelane = try queue.read { db in
                try db.tableExists("project") && db.tableExists("timeEntry")
            }
            guard isTimelane else { throw BackupError.notATimelaneDatabase }
            if try queue.read({ try migrator.hasBeenSuperseded($0) }) { throw BackupError.newerSchema }
            try migrator.migrate(queue)
        } catch let error as BackupError {
            throw error
        } catch is DatabaseError {
            // Not an SQLite file, or a damaged one.
            throw BackupError.notATimelaneDatabase
        }
    }
}
