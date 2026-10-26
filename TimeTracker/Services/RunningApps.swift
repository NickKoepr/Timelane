import AppKit

/// Apps the user can see in the Dock right now.
enum RunningApps {
    @MainActor static func regular() -> [ForegroundApp] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap(ForegroundApp.init)
    }
}
