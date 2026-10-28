import Foundation
import GRDB

extension AppEnvironment {
    /// In-memory database with sample data for SwiftUI previews.
    static func preview() -> AppEnvironment {
        do {
            let database = try AppDatabase.inMemory()
            try database.writer.write { db in
                var alpha = Project(name: "Project A", colorHex: "#4F8EF7")
                var beta = Project(name: "Internal / meetings", colorHex: "#34C759")
                try alpha.insert(db)
                try beta.insert(db)
                let today = Calendar.current.startOfDay(for: .now)
                func at(_ hour: Double) -> Date { today.addingTimeInterval(hour * 3600) }
                var entries = [
                    TimeEntry(projectId: alpha.id!, start: at(9), end: at(12)),
                    TimeEntry(projectId: beta.id!, start: at(13), end: at(14.5), note: "Standup"),
                ]
                for index in entries.indices { try entries[index].insert(db) }
                var session = AppSession(bundleIdentifier: "com.apple.dt.Xcode", appName: "Xcode", start: at(9), end: at(11))
                try session.insert(db)
                var xcode = TrackedApp(bundleIdentifier: "com.apple.dt.Xcode", name: "Xcode", projectId: alpha.id)
                var safari = TrackedApp(bundleIdentifier: "com.apple.Safari", name: "Safari")
                try xcode.insert(db)
                try safari.insert(db)
            }
            return AppEnvironment(database: database)
        } catch {
            fatalError("Preview database failed: \(error)")
        }
    }
}
