import AppKit

/// Restarts the app so a staged restore can replace the database (the swap happens in `AppDatabase.live()`).
@MainActor
enum AppRelauncher {
    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
            Task { @MainActor in
                if error == nil { NSApp.terminate(nil) } else { askToQuit() }
            }
        }
    }

    /// Opening a second instance failed: let the user finish the restore by hand.
    private static func askToQuit() {
        let alert = NSAlert()
        alert.messageText = "Restore is ready"
        alert.informativeText = "Quit and reopen Timelane to finish."
        alert.addButton(withTitle: "Quit Timelane")
        alert.addButton(withTitle: "Not Now")
        if alert.runModal() == .alertFirstButtonReturn { NSApp.terminate(nil) }
    }

    /// Called by a new instance before it opens the database: waits up to ~3 s for the old instance
    /// (the one that started this restart) to quit and release the file.
    nonisolated static func waitForOtherInstances() {
        guard let identifier = Bundle.main.bundleIdentifier else { return }
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            let others = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
                .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            if others.isEmpty { return }
            Thread.sleep(forTimeInterval: 0.1)
        }
    }
}
