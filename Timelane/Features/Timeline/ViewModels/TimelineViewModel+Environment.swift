import Foundation

extension TimelineViewModel {
    /// The timeline of the main window / iOS app, wired to the shared repositories, editor and timer.
    convenience init(environment: AppEnvironment) {
        self.init(
            timeEntries: environment.timeEntries,
            appSessions: environment.appSessions,
            projects: environment.projects,
            trackedApps: environment.trackedApps,
            editor: environment.timeEntryEditor,
            recordingTimer: environment.recordingTimer,
            liveAutoEntry: environment.liveAutoEntry)
    }
}
