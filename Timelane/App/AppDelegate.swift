import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Kept here: the notification center only holds its delegate weakly.
    private let reminderNotifications = ReminderNotificationDelegate()

    func applicationWillFinishLaunching(_ notification: Notification) {
        guard !AppEnvironment.isIsolatedRun else { return }
        reminderNotifications.install()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !AppEnvironment.isIsolatedRun else { return }
        Task { await AppEnvironment.shared.tracker.start() }
        Task { await AppEnvironment.shared.backup.run() }
        Task { await AppEnvironment.shared.reminders.refresh() }
    }

    /// Notifications may have been allowed or blocked in System Settings while Timelane was in the background.
    func applicationDidBecomeActive(_ notification: Notification) {
        guard !AppEnvironment.isIsolatedRun else { return }
        Task { await AppEnvironment.shared.reminders.refresh() }
    }

    /// Tracking and the menu bar item keep running when the window is closed.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !AppEnvironment.isIsolatedRun else { return .terminateNow }
        let tracker = AppEnvironment.shared.tracker
        let reply = TerminationReply()
        Task.detached {
            await tracker.stop()
            reply.send()
        }
        return .terminateLater
    }
}
