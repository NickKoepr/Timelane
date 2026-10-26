import Foundation
import Testing
@testable import Timelane

@MainActor
struct ZoomTransitionTests {
    @Test func easesFromStartToEnd() {
        let transition = ZoomTransition(from: 80, to: 480, duration: 0.2)
        #expect(transition.pointsPerHour(after: 0) == 80)
        #expect(transition.pointsPerHour(after: 0.1) == 280)          // halfway on the curve
        #expect(transition.pointsPerHour(after: 0.05) < 180)          // eases in: slower than linear
        #expect(transition.pointsPerHour(after: 0.2) == 480)
        #expect(transition.pointsPerHour(after: 5) == 480)
        #expect(!transition.isFinished(after: 0.19) && transition.isFinished(after: 0.2))
    }

    @Test func zeroDurationJumps() {
        let transition = ZoomTransition(from: 480, to: 80, duration: 0)
        #expect(transition.isFinished(after: 0))
        #expect(transition.pointsPerHour(after: 0) == 80)
    }

    @Test func stateAnimatesTowardsTheNewLevel() async throws {
        let state = TimelineZoomState(defaults: UserDefaults(suiteName: "Zoom-\(UUID())")!)
        state.animationDuration = 0.05
        state.set(.tenMinutes)
        #expect(state.zoom == .tenMinutes)
        #expect(state.isAnimating && state.pointsPerHour == 80)
        for _ in 0..<100 where state.isAnimating { try await Task.sleep(for: .milliseconds(10)) }
        #expect(!state.isAnimating && state.pointsPerHour == 480)
    }

    @Test func stateWithoutAnimationChangesAtOnce() {
        let state = TimelineZoomState(defaults: UserDefaults(suiteName: "Zoom-\(UUID())")!)
        state.set(.quarterHour)
        #expect(!state.isAnimating && state.pointsPerHour == 320)
    }
}
