import Foundation
import Testing
@testable import Timelane

struct IdleDetectorTests {
    let now = Date(timeIntervalSince1970: 1_000_000)

    @Test func emitsPauseOnceAtLastInputTime() {
        var detector = IdleDetector(threshold: 300)
        #expect(detector.evaluate(idleSeconds: 120, now: now) == nil)
        #expect(detector.evaluate(idleSeconds: 330, now: now) == .paused(.idle, at: now.addingTimeInterval(-330)))
        #expect(detector.evaluate(idleSeconds: 360, now: now) == nil)
    }

    @Test func emitsResumeWhenInputReturns() {
        var detector = IdleDetector(threshold: 300)
        _ = detector.evaluate(idleSeconds: 400, now: now)
        #expect(detector.evaluate(idleSeconds: 2, now: now) == .resumed(.idle))
        #expect(detector.evaluate(idleSeconds: 3, now: now) == nil)
    }
}
