import Foundation

/// Composition root: the one place where database, repositories and services are wired together.
@MainActor @Observable
final class AppEnvironment {
    let database: AppDatabase
    let projects: any ProjectRepository
    let timeEntries: any TimeEntryRepository
    let appSessions: any AppSessionRepository
    let trackedApps: any TrackedAppRepository
    /// The shared editor of the main window and the menu bar: the only one that records undo history.
    /// Other writers (e.g. automatic logging) must use their own `TimeEntryEditor(repository:)` without `onChange`.
    let timeEntryEditor: TimeEntryEditor
    let timeEntryHistory: TimeEntryHistory
    let tracker: AppActivityTracker
    /// The one Record/Stop timer, shared by the main window and the menu bar panel.
    let recordingTimer: RecordingTimer
    /// Set by the menu bar to open the main window on a specific screen; `RootView` consumes it.
    var requestedSidebarItem: SidebarItem?
    /// Set by the Overview heatmap to open the Timeline on a specific day; `TimelineScreen` consumes it.
    var requestedTimelineDay: Date?

    init(database: AppDatabase, recordingTimerStore: any RecordingTimerStore = InMemoryRecordingTimerStore(),
         autoLogStore: any AutoLogStateStore = InMemoryAutoLogStateStore()) {
        self.database = database
        self.recordingTimer = RecordingTimer(store: recordingTimerStore)
        self.projects = GRDBProjectRepository(database: database)
        self.timeEntries = GRDBTimeEntryRepository(database: database)
        self.appSessions = GRDBAppSessionRepository(database: database)
        self.trackedApps = GRDBTrackedAppRepository(database: database)
        let history = TimeEntryHistory(repository: timeEntries)
        self.timeEntryHistory = history
        self.timeEntryEditor = TimeEntryEditor(repository: timeEntries, onChange: { change in
            await history.record(change)
        })
        self.tracker = AppActivityTracker(
            repository: appSessions, trackedApps: trackedApps,
            autoLogger: AutoTimeLogger(timeEntries: timeEntries, trackedApps: trackedApps, store: autoLogStore))
    }

    /// The environment of the running app (shared with the app delegate).
    /// Unit tests that host the app get an empty in-memory database and no tracking.
    static let shared: AppEnvironment = isRunningTests ? inMemory() : live()

    nonisolated static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    static func live() -> AppEnvironment {
        do {
            return AppEnvironment(database: try AppDatabase.live(), recordingTimerStore: UserDefaultsRecordingTimerStore(),
                                  autoLogStore: UserDefaultsAutoLogStateStore())
        } catch {
            fatalError("Could not open the Timelane database: \(error)")
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
