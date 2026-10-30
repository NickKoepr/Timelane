import Foundation
import GRDB
@testable import Timelane

enum BackupFixtures {
    static func info(projects: Int = 1, entries: Int = 1, createdAt: Date = Date(timeIntervalSince1970: 1_000)) -> BackupInfo {
        BackupInfo(createdAt: createdAt, deviceName: "Test Mac", appVersion: "1.0 (1)", schemaVersion: "v3",
                   projectCount: projects, timeEntryCount: entries)
    }

    /// An in-memory database with `projects` projects and `entries` entries.
    static func database(projects: Int, entries: Int) throws -> AppDatabase {
        let database = try AppDatabase.inMemory()
        try database.writer.write { db in
            for index in 0..<projects {
                var project = Project(name: "Project \(index)", colorHex: "#4F8EF7")
                try project.insert(db)
            }
            for index in 0..<entries {
                var entry = TimeEntry(projectId: 1, start: Date(timeIntervalSince1970: Double(index) * 7200),
                                      end: Date(timeIntervalSince1970: Double(index) * 7200 + 3600))
                try entry.insert(db)
            }
        }
        return database
    }

    static func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("TimelaneTest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func snapshot(of database: AppDatabase) throws -> (file: URL, info: BackupInfo, directory: URL) {
        let directory = try temporaryDirectory()
        let result = try BackupSnapshotter(database: database)
            .makeSnapshot(in: directory, deviceName: "Test Mac", appVersion: "1.0 (1)")
        return (result.file, result.info, directory)
    }
}
