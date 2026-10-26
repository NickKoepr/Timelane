import Foundation

/// What the tracker is doing right now, as shown in the menu bar panel.
enum TrackingStatus: Equatable {
    /// The frontmost app is tracked and a session is being recorded.
    case tracking(appName: String)
    /// The frontmost app is not on the tracked list (or there is no frontmost app).
    case notTracked(appName: String?)
    /// Tracking is suspended (idle, sleep, screen lock).
    case paused

    init(isPaused: Bool, currentApp: ForegroundApp?, isCurrentAppTracked: Bool) {
        if isPaused {
            self = .paused
        } else if let app = currentApp, isCurrentAppTracked {
            self = .tracking(appName: app.name)
        } else {
            self = .notTracked(appName: currentApp?.name)
        }
    }

    var text: String {
        switch self {
        case .tracking(let name): name
        case .notTracked(let name): name.map { "Not tracking: \($0)" } ?? "Not tracking"
        case .paused: "Paused"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .tracking(let name): "Recording \(name)"
        case .notTracked(let name): name.map { "Not tracking \($0)" } ?? "Not tracking"
        case .paused: "Tracking paused"
        }
    }
}
