import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !AppEnvironment.isIsolatedRun else { return }
        Task { await AppEnvironment.shared.tracker.start() }
        Task { await AppEnvironment.shared.backup.run() }
    }

    /// Tracking and the menu bar item keep running when the window is closed.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !AppEnvironment.isIsolatedRun else { return .terminateNow }
        Task {
            await AppEnvironment.shared.tracker.stop()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
