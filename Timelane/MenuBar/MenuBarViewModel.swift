#if os(macOS)
import Foundation

/// What the menu bar panel adds on top of the timeline: its own `TimelineViewModel` (own zoom level)
/// and "show today again" every time the panel opens.
@MainActor @Observable
final class MenuBarViewModel {
    static let zoomKey = "menuBarTimelineZoomLevel"

    let timeline: TimelineViewModel
    /// Increases whenever the panel opened and the timeline should scroll back to "now".
    private(set) var scrollTrigger = 0

    /// Told when the panel opens (true) or closes (false); the app uses it to poll iCloud only while it is open.
    private let onVisibilityChange: @MainActor (Bool) -> Void

    init(timeline: TimelineViewModel, onVisibilityChange: @escaping @MainActor (Bool) -> Void = { _ in }) {
        self.timeline = timeline
        self.onVisibilityChange = onVisibilityChange
    }

    static func make(environment: AppEnvironment, defaults: UserDefaults = .standard) -> MenuBarViewModel {
        MenuBarViewModel(timeline: TimelineViewModel(
            timeEntries: environment.timeEntries, appSessions: environment.appSessions,
            projects: environment.projects, trackedApps: environment.trackedApps, editor: environment.timeEntryEditor,
            zoomState: TimelineZoomState(defaults: defaults, key: zoomKey, defaultLevel: .halfHour),
            allowsCreatingProjects: false, recordingTimer: environment.recordingTimer,
            liveAutoEntry: environment.liveAutoEntry),
            onVisibilityChange: { [sync = environment.sync] visible in sync.setPolling(visible, for: .menuBar) })
    }

    /// The panel became visible: jump to today around "now". An unfinished form is left alone, so closing
    /// the panel by accident does not lose what was typed.
    func panelDidOpen() {
        onVisibilityChange(true)
        guard timeline.form == nil else { return }
        timeline.goToToday()
        scrollTrigger += 1
    }

    func panelDidClose() {
        onVisibilityChange(false)
    }
}
#endif
