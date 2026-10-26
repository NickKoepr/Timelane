import Foundation

extension AppActivityTracker {
    /// The state shown in the menu bar panel; red recording dot only for `.tracking`.
    var status: TrackingStatus {
        TrackingStatus(isPaused: isPaused, currentApp: currentApp, isCurrentAppTracked: isCurrentAppTracked)
    }
}
