import Foundation

/// What the menu bar panel adds on top of the timeline: its own `TimelineViewModel` (own zoom level)
/// and "show today again" every time the panel opens.
@MainActor @Observable
final class MenuBarViewModel {
    static let zoomKey = "menuBarTimelineZoomLevel"

    let timeline: TimelineViewModel
    /// Increases whenever the panel opened and the timeline should scroll back to "now".
    private(set) var scrollTrigger = 0

    init(timeline: TimelineViewModel) {
        self.timeline = timeline
    }

    static func make(environment: AppEnvironment, defaults: UserDefaults = .standard) -> MenuBarViewModel {
        MenuBarViewModel(timeline: TimelineViewModel(
            timeEntries: environment.timeEntries, appSessions: environment.appSessions,
            projects: environment.projects, trackedApps: environment.trackedApps, editor: environment.timeEntryEditor,
            zoomState: TimelineZoomState(defaults: defaults, key: zoomKey, defaultLevel: .halfHour),
            allowsCreatingProjects: false, recordingTimer: environment.recordingTimer))
    }

    /// The panel became visible: jump to today around "now". An unfinished form is left alone, so closing
    /// the panel by accident does not lose what was typed.
    func panelDidOpen() {
        guard timeline.form == nil else { return }
        timeline.goToToday()
        scrollTrigger += 1
    }
}
