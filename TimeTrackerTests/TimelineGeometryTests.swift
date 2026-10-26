import CoreGraphics
import Foundation
import Testing
@testable import TimeTracker

struct TimelineGeometryTests {
    let cal = TestCalendar.make()
    func d(_ m: Int, _ day: Int, _ h: Int, _ min: Int = 0) -> Date { TestCalendar.date(2026, m, day, h, min, calendar: cal) }
    func geometry(_ m: Int = 11, _ day: Int = 3) -> TimelineGeometry {
        TimelineGeometry(day: .day(of: d(m, day, 12), calendar: cal))
    }

    @Test func yAndDateAreInverse() {
        let g = geometry()
        #expect(g.y(for: d(11, 3, 0)) == 0)
        #expect(g.y(for: d(11, 3, 9, 30)) == 9.5 * 80)
        #expect(g.date(forY: 760) == d(11, 3, 9, 30))
        #expect(g.totalHeight == CGFloat(24 * 80))
    }

    @Test func clampsToDay() {
        let g = geometry()
        #expect(g.y(for: d(11, 2, 12)) == 0)
        #expect(g.y(for: d(11, 4, 12)) == g.totalHeight)
        #expect(g.date(forY: -50) == g.day.start)
        #expect(g.date(forY: 99_999) == g.day.end)
    }

    @Test func snapsToFiveMinutes() {
        let g = geometry()
        #expect(g.snapped(d(11, 3, 10, 2)) == d(11, 3, 10, 0))
        #expect(g.snapped(d(11, 3, 10, 3)) == d(11, 3, 10, 5))
        #expect(g.snapped(d(11, 3, 10, 7)) == d(11, 3, 10, 5))
    }

    @Test func frameIsClippedToDay() {
        let g = geometry()
        let frame = g.frame(for: d(11, 2, 23), end: d(11, 3, 1))
        #expect(frame.y == 0)
        #expect(frame.height == 80)
    }

    @Test func dstDaysFollowRealDuration() {
        #expect(geometry(3, 29).totalHeight == CGFloat(23 * 80))
        #expect(geometry(10, 25).totalHeight == CGFloat(25 * 80))
        let g = geometry(3, 29)
        // 03:00 local exists as the 3rd hour of the day (02:00 is skipped).
        #expect(g.y(for: d(3, 29, 3)) == CGFloat(2 * 80))
    }
}
