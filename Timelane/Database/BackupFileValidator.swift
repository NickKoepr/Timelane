import Foundation
import GRDB

/// Checks that a downloaded backup is a Timelane database this version can read, and upgrades an older schema
/// in place (a legacy backup may be from v1–v4; the migrations give it sync ids like a live database).
enum BackupFileValidator {
    static func validateAndMigrate(_ file: URL) throws {
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
