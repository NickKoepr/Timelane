import AppKit

extension AppEnvironment {
    /// Brings the main window forward on today's timeline (a click on a reminder notification).
    /// Opening a closed main window needs the `openWindow` a view registered (`registersMainWindowOpener`).
    func showTodayOnTimeline() {
        requestedTimelineDay = .now
        requestedSidebarItem = .timeline
        openMainWindow?()
        NSApp.activate()
    }
}
