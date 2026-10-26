import Testing
@testable import Timelane

struct TrackingStatusTests {
    let xcode = ForegroundApp(bundleIdentifier: "com.apple.dt.Xcode", name: "Xcode")
    let safari = ForegroundApp(bundleIdentifier: "com.apple.Safari", name: "Safari")

    @Test func pausedWinsOverEverything() {
        #expect(TrackingStatus(isPaused: true, currentApp: xcode, isCurrentAppTracked: true) == .paused)
        #expect(TrackingStatus(isPaused: true, currentApp: nil, isCurrentAppTracked: false) == .paused)
    }

    @Test func trackedAppIsTracking() {
        let status = TrackingStatus(isPaused: false, currentApp: xcode, isCurrentAppTracked: true)
        #expect(status == .tracking(appName: "Xcode"))
        #expect(status.text == "Xcode")
        #expect(status.accessibilityLabel == "Recording Xcode")
    }

    @Test func untrackedAppIsNotTracked() {
        let status = TrackingStatus(isPaused: false, currentApp: safari, isCurrentAppTracked: false)
        #expect(status == .notTracked(appName: "Safari"))
        #expect(status.text == "Not tracking: Safari")
        #expect(status.accessibilityLabel == "Not tracking Safari")
    }

    @Test func noAppIsNotTrackedWithoutName() {
        let status = TrackingStatus(isPaused: false, currentApp: nil, isCurrentAppTracked: false)
        #expect(status == .notTracked(appName: nil))
        #expect(status.text == "Not tracking")
    }

    @Test func pausedText() {
        #expect(TrackingStatus.paused.text == "Paused")
        #expect(TrackingStatus.paused.accessibilityLabel == "Tracking paused")
    }
}
