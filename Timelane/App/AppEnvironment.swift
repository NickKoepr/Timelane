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
    /// Opt-in iCloud backup (off by default); also drives the Settings window.
    let backup: CloudBackupService
    /// Set by the menu bar to open the main window on a specific screen; `RootView` consumes it.
    var requestedSidebarItem: SidebarItem?
    /// Set by the Overview heatmap to open the Timeline on a specific day; `TimelineScreen` consumes it.
    var requestedTimelineDay: Date?
    /// Whether the welcome carousel is presented by `RootView`; on for a first launch, or via Help.
    var isShowingOnboarding = false
    let onboardingStore: OnboardingStore

    /// Id of the entry the auto logger is growing; the timelines draw it live.
    let liveAutoEntry = LiveAutoEntry()

    init(database: AppDatabase, recordingTimerStore: any RecordingTimerStore = InMemoryRecordingTimerStore(),
         autoLogStore: any AutoLogStateStore = InMemoryAutoLogStateStore(),
         backupStore: any CloudBackupStore = InMemoryCloudBackupStore(),
         backupSettings: any BackupSettingsStore = InMemoryBackupSettingsStore(),
         pendingRestore: PendingRestore = .temporary(),
         onboardingStore: OnboardingStore = .temporary()) {
        self.database = database
        self.onboardingStore = onboardingStore
        self.backup = Self.makeBackup(database: database, store: backupStore, settings: backupSettings,
                                      pendingRestore: pendingRestore)
        self.recordingTimer = RecordingTimer(store: recordingTimerStore)
        self.projects = GRDBProjectRepository(database: database)
        self.timeEntries = GRDBTimeEntryRepository(database: database)
        self.appSessions = GRDBAppSessionRepository(database: database)
        self.trackedApps = GRDBTrackedAppRepository(database: database)
        let live = liveAutoEntry
        let history = TimeEntryHistory(repository: timeEntries)
        self.timeEntryHistory = history
        self.timeEntryEditor = TimeEntryEditor(repository: timeEntries, onChange: { change in
            await history.record(change)
        })
        self.tracker = AppActivityTracker(
            repository: appSessions, trackedApps: trackedApps,
            autoLogger: AutoTimeLogger(timeEntries: timeEntries, trackedApps: trackedApps, store: autoLogStore, live: live))
    }

    /// The environment of the running app (shared with the app delegate).
    /// Unit tests that host the app get an empty in-memory database and no tracking.
    static let shared: AppEnvironment = {
        if isRunningTests { return inMemory() }
        #if DEBUG
        if ScreenshotMode.isMisconfigured { fatalError("Invalid -screenshotScene / -screenshotOutput arguments") }
        if ScreenshotMode.isActive { return screenshot() }
        #endif
        return live()
    }()

    /// Tests and the DEBUG screenshot mode run without tracking, backups or the real database.
    nonisolated static var isIsolatedRun: Bool {
        #if DEBUG
        if ScreenshotMode.isActive { return true }
        #endif
        return isRunningTests
    }

    nonisolated static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    static func live() -> AppEnvironment {
        do {
            let directory = try AppDatabase.liveDirectory()
            let pendingRestore = PendingRestore(directory: directory)
            // After a restore the previous instance may still be closing the database file.
            let autoLogStore = UserDefaultsAutoLogStateStore()
            if pendingRestore.hasPendingRestore {
                AppRelauncher.waitForOtherInstances()
                // The saved auto-log entry id refers to the old database; in the restored one it may be another entry.
                autoLogStore.state = AutoLogState()
            }
            let onboardingStore = OnboardingStore()
            let environment = AppEnvironment(database: try AppDatabase.live(), recordingTimerStore: UserDefaultsRecordingTimerStore(),
                                  autoLogStore: autoLogStore,
                                  backupStore: CloudKitBackupStore(), backupSettings: UserDefaultsBackupSettingsStore(),
                                  pendingRestore: pendingRestore, onboardingStore: onboardingStore)
            environment.isShowingOnboarding = !onboardingStore.hasCompleted
            return environment
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
