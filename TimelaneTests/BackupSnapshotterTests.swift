import Foundation
import GRDB
import Testing
@testable import Timelane

struct BackupSnapshotterTests {
    @Test func snapshotHasSameRowsAndDescribesThem() throws {
        let database = try BackupFixtures.database(projects: 2, entries: 3)
        let (file, info, directory) = try BackupFixtures.snapshot(of: database)
        defer { try? FileManager.default.removeItem(at: directory) }

        #expect(info.projectCount == 2)
        #expect(info.timeEntryCount == 3)
        #expect(info.deviceName == "Test Mac")
        #expect(info.schemaVersion == Migrations.makeMigrator().migrations.last)

        let copy = try DatabaseQueue(path: file.path)
        try copy.read { db in
            let value1 = try Project.fetchCount(db)
            #expect(value1 == 2)
            let value2 = try TimeEntry.fetchAll(db).count
            #expect(value2 == 3)
        }
    }

    @Test func emptyDatabaseHasNoData() throws {
        let (_, info, directory) = try BackupFixtures.snapshot(of: try AppDatabase.inMemory())
        defer { try? FileManager.default.removeItem(at: directory) }
        #expect(!info.hasData)
    }
}
