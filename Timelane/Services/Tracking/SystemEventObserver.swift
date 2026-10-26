import AppKit

/// Translates workspace, sleep/wake and screen-lock notifications into `ActivityEvent`s.
final class SystemEventObserver {
    private var observations: [(center: NotificationCenter, token: NSObjectProtocol)] = []

    private let sink: @Sendable (ActivityEvent) -> Void

    init(sink: @escaping @Sendable (ActivityEvent) -> Void) {
        self.sink = sink
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.didActivateApplicationNotification) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            return app.flatMap(ForegroundApp.init)
                .map { .appActivated($0) }
        }
        let pairs: [(Notification.Name, ActivityEvent)] = [
            (NSWorkspace.willSleepNotification, .paused(.sleep)),
            (NSWorkspace.didWakeNotification, .resumed(.sleep)),
            (NSWorkspace.screensDidSleepNotification, .paused(.screenOff)),
            (NSWorkspace.screensDidWakeNotification, .resumed(.screenOff)),
            (NSWorkspace.sessionDidResignActiveNotification, .paused(.sessionInactive)),
            (NSWorkspace.sessionDidBecomeActiveNotification, .resumed(.sessionInactive)),
        ]
        for (name, event) in pairs { observe(workspace, name) { _ in event } }

        let distributed = DistributedNotificationCenter.default()
        observe(distributed, .init("com.apple.screenIsLocked")) { _ in .paused(.locked) }
        observe(distributed, .init("com.apple.screenIsUnlocked")) { _ in .resumed(.locked) }
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name,
                         map: @escaping @Sendable (Notification) -> ActivityEvent?) {
        let sink = self.sink
        let token = center.addObserver(forName: name, object: nil, queue: .main) { note in
            if let event = map(note) { sink(event) }
        }
        observations.append((center, token))
    }

    func stop() {
        observations.forEach { $0.center.removeObserver($0.token) }
        observations.removeAll()
    }

    deinit { stop() }
}

extension ForegroundApp {
    init?(_ app: NSRunningApplication) {
        let name = app.localizedName ?? app.bundleIdentifier
        guard let name else { return nil }
        self.init(bundleIdentifier: app.bundleIdentifier ?? "unknown.\(name)", name: name)
    }
}
