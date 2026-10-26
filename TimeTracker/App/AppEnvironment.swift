import Foundation

/// Composition root: the one place where database, repositories and services are wired together.
@MainActor @Observable
final class AppEnvironment {
    let database: AppDatabase
    let projects: any ProjectRepository
    let timeEntries: any TimeEntryRepository
    let appSessions: any AppSessionRepository

    init(database: AppDatabase) {
        self.database = database
        self.projects = GRDBProjectRepository(database: database)
        self.timeEntries = GRDBTimeEntryRepository(database: database)
        self.appSessions = GRDBAppSessionRepository(database: database)
    }

    static func live() -> AppEnvironment {
        do {
            return AppEnvironment(database: try AppDatabase.live())
        } catch {
            fatalError("Could not open the TimeTracker database: \(error)")
        }
    }
}
