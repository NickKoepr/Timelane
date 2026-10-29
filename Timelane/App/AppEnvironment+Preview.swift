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
                // Earlier weekdays, so the Overview heatmap has something to show.
                for offset in 1...120 {
                    guard let day = Calendar.current.date(byAdding: .day, value: -offset, to: today),
                          !Calendar.current.isDateInWeekend(day) else { continue }
                    let hours = Double(2 + (offset * 7) % 6)
                    let project = offset % 3 == 0 ? beta : alpha
                    entries.append(TimeEntry(projectId: project.id!, start: day.addingTimeInterval(9 * 3600),
                                             end: day.addingTimeInterval((9 + hours) * 3600)))
                }
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
