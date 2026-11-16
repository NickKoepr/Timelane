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

    static func snapshot(of database: AppDatabase, part: BackupPart = .projectsAndHours,
                         createdAt: Date = .now) throws -> (file: URL, info: BackupInfo, directory: URL) {
        let directory = try temporaryDirectory()
        if part == .legacy {
            // What older versions uploaded: the whole database.
            let file = directory.appendingPathComponent("whole.sqlite")
            try BackupSnapshotter(database: database).copyWholeDatabase(to: file)
            let info = try database.writer.read { db in
                BackupInfo(createdAt: createdAt, deviceName: "Old Mac", appVersion: "1.0 (1)", schemaVersion: "v5",
                           projectCount: try Project.fetchCount(db), timeEntryCount: try TimeEntry.fetchCount(db))
            }
            return (file, info, directory)
        }
        let result = try BackupSnapshotter(database: database)
            .makeSnapshot(part, in: directory, deviceName: "Test Mac", appVersion: "1.0 (1)", now: createdAt)
        return (result.file, result.info, directory)
    }

    /// Puts a snapshot of `database` into `store` as `part`.
    @discardableResult
    static func seedSnapshot(of database: AppDatabase, part: BackupPart, into store: InMemoryCloudBackupStore,
                             createdAt: Date = .now) throws -> BackupInfo {
        let (file, info, directory) = try snapshot(of: database, part: part, createdAt: createdAt)
        defer { try? FileManager.default.removeItem(at: directory) }
        try store.seed(part, file: file, info: info)
        return info
    }

    /// Adds an app session.
    static func addSession(_ database: AppDatabase, bundle: String = "com.apple.dt.Xcode", from start: Double,
                           to end: Double) throws {
        try database.writer.write { db in
            var session = AppSession(bundleIdentifier: bundle, appName: "App", start: Date(timeIntervalSince1970: start),
                                     end: Date(timeIntervalSince1970: end))
            try session.insert(db)
        }
    }

    static func sessionCount(_ database: AppDatabase) throws -> Int {
        try database.writer.read { db in try AppSession.fetchCount(db) }
    }
}

extension SyncTestDevice {
    /// A backup service for this device; `backsUpActivity` false plays an iPhone.
    func backupService(store: InMemoryCloudBackupStore, backsUpActivity: Bool = true,
                       settings: InMemoryBackupSettingsStore = InMemoryBackupSettingsStore(),
                       now: @escaping () -> Date = { .now }, deviceName: String = "Test Mac") -> CloudBackupService {
        CloudBackupService(
            snapshotter: BackupSnapshotter(database: database), merger: ActivityBackupMerger(database: database),
            store: store, settings: settings, sync: service,
            safetyCopy: FileManager.default.temporaryDirectory
                .appendingPathComponent("TimelaneSafety-\(UUID().uuidString)/db-before-restore.sqlite"),
            backsUpActivity: backsUpActivity, now: now, deviceName: deviceName)
    }
}
