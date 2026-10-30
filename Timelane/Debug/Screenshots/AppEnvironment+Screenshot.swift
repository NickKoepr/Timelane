#if DEBUG
import Foundation
import GRDB

extension AppEnvironment {
    /// In-memory database with `ScreenshotSampleData`; iCloud backup shows as on (in-memory store, nothing is uploaded).
    static func screenshot(data: ScreenshotSampleData = ScreenshotMode.sampleData) -> AppEnvironment {
        do {
            let database = try AppDatabase.inMemory()
            try database.writer.write { db in
                for var project in data.projects { try project.insert(db) }
                for var app in data.trackedApps { try app.insert(db) }
                for var entry in data.entries { try entry.insert(db) }
                for var session in data.sessions { try session.insert(db) }
            }
            let settings = InMemoryBackupSettingsStore(isEnabled: true, lastBackupAt: .now.addingTimeInterval(-7 * 60))
            return AppEnvironment(database: database, backupSettings: settings)
        } catch {
            fatalError("Screenshot database failed: \(error)")
        }
    }
}
#endif
