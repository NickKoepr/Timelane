import Foundation
import GRDB
import Testing
@testable import Timelane

struct PendingRestoreTests {
    private func makeRestore() throws -> (PendingRestore, URL) {
        let directory = try BackupFixtures.temporaryDirectory()
        return (PendingRestore(directory: directory), directory)
    }

    private func snapshotFile(projects: Int = 2, entries: Int = 3) throws -> (URL, URL) {
        let result = try BackupFixtures.snapshot(of: BackupFixtures.database(projects: projects, entries: entries))
        return (result.file, result.directory)
    }

    @Test func stagingValidSnapshotCreatesPendingFile() throws {
        let (restore, directory) = try makeRestore()
        let (file, source) = try snapshotFile()
        defer { for url in [directory, source] { try? FileManager.default.removeItem(at: url) } }
        #expect(!restore.hasPendingRestore)
        try restore.stage(file)
        #expect(restore.hasPendingRestore)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func stagingGarbageThrows() throws {
        let (restore, directory) = try makeRestore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let garbage = directory.appendingPathComponent("garbage.sqlite")
        try Data("this is not a database, just some text that is long enough".utf8).write(to: garbage)
        #expect(throws: BackupError.notATimelaneDatabase) { try restore.stage(garbage) }
        #expect(!restore.hasPendingRestore)
    }

    @Test func stagingForeignDatabaseThrows() throws {
        let (restore, directory) = try makeRestore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let foreign = directory.appendingPathComponent("foreign.sqlite")
        let queue = try DatabaseQueue(path: foreign.path)
        try queue.write { try $0.execute(sql: "CREATE TABLE other (id INTEGER)") }
        #expect(throws: BackupError.notATimelaneDatabase) { try restore.stage(foreign) }
    }

    @Test func stagingNewerSchemaThrows() throws {
        let (restore, directory) = try makeRestore()
        let (file, source) = try snapshotFile()
        defer { for url in [directory, source] { try? FileManager.default.removeItem(at: url) } }
        let queue = try DatabaseQueue(path: file.path)
        try queue.write { try $0.execute(sql: "INSERT INTO grdb_migrations (identifier) VALUES ('v99')") }
        #expect(throws: BackupError.newerSchema) { try restore.stage(file) }
        #expect(!restore.hasPendingRestore)
    }

    @Test func stagingUpgradesOlderSchema() throws {
        let (restore, directory) = try makeRestore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let old = directory.appendingPathComponent("old.sqlite")
        let queue = try DatabaseQueue(path: old.path)
        try Migrations.makeMigrator().migrate(queue, upTo: "v1")
        try queue.write { try $0.execute(sql: "INSERT INTO project (name, colorHex, isArchived, createdAt) VALUES ('P', '#FFFFFF', 0, 0)") }

        try restore.stage(old)
        let staged = try DatabaseQueue(path: restore.pendingFile.path)
        try staged.read { db in
            let value1 = try db.tableExists("trackedApp")
            #expect(value1)
            let value2 = try Project.fetchCount(db)
            #expect(value2 == 1)
        }
    }

    @Test func applySwapsFilesAndKeepsThePreviousDatabase() throws {
        let (restore, directory) = try makeRestore()
        let (file, source) = try snapshotFile(projects: 2, entries: 3)
        defer { for url in [directory, source] { try? FileManager.default.removeItem(at: url) } }
        let databaseFile = directory.appendingPathComponent("db.sqlite")
        let current = try AppDatabase.file(at: databaseFile)
        try current.writer.write { db in var p = Project(name: "Old", colorHex: "#000000"); try p.insert(db) }

        #expect(try !restore.applyIfPending(databaseFile: databaseFile))
        try restore.stage(file)
        #expect(try restore.applyIfPending(databaseFile: databaseFile))
        #expect(!restore.hasPendingRestore)

        let restored = try AppDatabase.file(at: databaseFile)
        try restored.writer.read { db in
            let value3 = try Project.fetchCount(db)
            #expect(value3 == 2)
            let value4 = try TimeEntry.fetchCount(db)
            #expect(value4 == 3)
        }
        let previous = try DatabaseQueue(path: directory.appendingPathComponent(PendingRestore.previousName).path)
        try previous.read { db in
            let value5 = try Project.fetchAll(db).map(\.name)
            #expect(value5 == ["Old"])
        }
    }
}
