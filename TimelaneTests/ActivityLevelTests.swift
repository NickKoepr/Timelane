import Testing
@testable import Timelane

struct ActivityLevelTests {
    @Test func boundaries() {
        let h = 3600.0
        #expect(ActivityLevel(seconds: 0) == .none)
        #expect(ActivityLevel(seconds: 1) == .low)
        #expect(ActivityLevel(seconds: 2 * h - 1) == .low)
        #expect(ActivityLevel(seconds: 2 * h) == .medium)
        #expect(ActivityLevel(seconds: 4 * h) == .high)
        #expect(ActivityLevel(seconds: 6 * h) == .max)
        #expect(ActivityLevel(seconds: 12 * h) == .max)
    }
}
