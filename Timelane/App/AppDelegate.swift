#if os(macOS)
import AppKit
import Observation

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !AppEnvironment.isIsolatedRun else { return }
        Task { await AppEnvironment.shared.tracker.start() }
        Task { await AppEnvironment.shared.backup.run() }
        Task {
            await AppEnvironment.shared.sync.load()
            await MainActor.run { Self.watchSyncEnabled() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in await AppEnvironment.shared.sync.syncNow() }   // no-op while sync is off
        }
    }

    /// A silent push from iCloud: the sync engine handles it itself, a sync pass is a cheap extra.
    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String: Any]) {
        guard !AppEnvironment.isIsolatedRun else { return }
        Task { @MainActor in await AppEnvironment.shared.sync.syncNow() }
    }

    /// Registers for pushes whenever sync is (or becomes) enabled, so changes from other devices arrive quickly.
    @MainActor
    private static func watchSyncEnabled() {
        let sync = AppEnvironment.shared.sync
        if sync.isEnabled { NSApplication.shared.registerForRemoteNotifications() }
        withObservationTracking {
            _ = sync.isEnabled
        } onChange: {
            Task { @MainActor in watchSyncEnabled() }
        }
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
#endif
