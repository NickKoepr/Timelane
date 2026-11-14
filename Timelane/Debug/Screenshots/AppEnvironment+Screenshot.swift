#if DEBUG
import Foundation
import GRDB

extension AppEnvironment {
    /// In-memory database with `ScreenshotSampleData`; iCloud shows as on (sync is isolated and the backup store is in
    /// memory, so nothing leaves the Mac).
    static func screenshot(data: ScreenshotSampleData = ScreenshotMode.sampleData) -> AppEnvironment {
        do {
            let database = try AppDatabase.inMemory()
            try database.writer.write { db in
                for var project in data.projects { try project.insert(db) }
                for var app in data.trackedApps { try app.insert(db) }
                for var entry in data.entries { try entry.insert(db) }
                for var session in data.sessions { try session.insert(db) }
            }
            let environment = AppEnvironment(database: database)
            let backupTime = Date.now.addingTimeInterval(-7 * 60)
            environment.sync.isEnabled = true
            environment.sync.lastSync = .now.addingTimeInterval(-40)
            environment.backup.remote = [
                .projectsAndHours: BackupInfo(createdAt: backupTime, deviceName: DeviceName.current, appVersion: "",
                                              schemaVersion: "", projectCount: data.projects.count,
                                              timeEntryCount: data.entries.count),
                .appActivity: BackupInfo(createdAt: backupTime, deviceName: DeviceName.current, appVersion: "",
                                         schemaVersion: "", projectCount: data.projects.count, timeEntryCount: 0),
            ]
            return environment
        } catch {
            fatalError("Screenshot database failed: \(error)")
        }
    }
}
#endif
