import Foundation

/// Composition root: the one place where database, repositories and services are wired together.
@MainActor @Observable
final class AppEnvironment {
    let database: AppDatabase
    let projects: any ProjectRepository
    let timeEntries: any TimeEntryRepository
    let appSessions: any AppSessionRepository
    let timeEntryEditor: TimeEntryEditor
    let tracker: AppActivityTracker

    init(database: AppDatabase) {
        self.database = database
        self.projects = GRDBProjectRepository(database: database)
        self.timeEntries = GRDBTimeEntryRepository(database: database)
        self.appSessions = GRDBAppSessionRepository(database: database)
        self.timeEntryEditor = TimeEntryEditor(repository: timeEntries)
        self.tracker = AppActivityTracker(repository: appSessions)
    }

    /// The environment of the running app (shared with the app delegate).
    /// Unit tests that host the app get an empty in-memory database and no tracking.
    static let shared: AppEnvironment = isRunningTests ? inMemory() : live()

    nonisolated static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    static func live() -> AppEnvironment {
        do {
            return AppEnvironment(database: try AppDatabase.live())
        } catch {
            fatalError("Could not open the TimeTracker database: \(error)")
        }
    }

    static func inMemory() -> AppEnvironment {
        do {
            return AppEnvironment(database: try AppDatabase.inMemory())
        } catch {
            fatalError("Could not create the in-memory database: \(error)")
        }
    }
}
