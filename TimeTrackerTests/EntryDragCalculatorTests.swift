import CoreGraphics
import Foundation
import Testing
@testable import TimeTracker

struct EntryDragCalculatorTests {
    let cal = TestCalendar.make()
    func d(_ h: Int, _ m: Int = 0) -> Date { TestCalendar.date(2026, 11, 3, h, m, calendar: cal) }
    var geometry: TimelineGeometry { TimelineGeometry(day: .day(of: d(12), calendar: cal)) }  // 80pt/hour
    let original: DateRange
    let minimum: TimeInterval = 300

    init() {
        let day = TestCalendar.date(2026, 11, 3)
        original = DateRange(start: day.addingTimeInterval(10 * 3600), end: day.addingTimeInterval(12 * 3600))
    }

    @Test func moveKeepsDurationAndSnaps() {
        let result = EntryDragCalculator.range(for: .move, original: original, translationY: 40 + 2, geometry: geometry, minimumDuration: minimum)
        #expect(result.start == d(10, 30))
        #expect(result.end == d(12, 30))
    }

    @Test func moveIsClampedToDay() {
        let late = EntryDragCalculator.range(for: .move, original: original, translationY: 80 * 20, geometry: geometry, minimumDuration: minimum)
        #expect(late.end == geometry.day.end)
        #expect(late.duration == 2 * 3600)
        let early = EntryDragCalculator.range(for: .move, original: original, translationY: -80 * 20, geometry: geometry, minimumDuration: minimum)
        #expect(early.start == geometry.day.start)
        #expect(early.duration == 2 * 3600)
    }

    @Test func resizeTopChangesOnlyStart() {
        let result = EntryDragCalculator.range(for: .resizeTop, original: original, translationY: -80, geometry: geometry, minimumDuration: minimum)
        #expect(result.start == d(9))
        #expect(result.end == original.end)
    }

    @Test func resizeBottomChangesOnlyEnd() {
        let result = EntryDragCalculator.range(for: .resizeBottom, original: original, translationY: 40, geometry: geometry, minimumDuration: minimum)
        #expect(result.start == original.start)
        #expect(result.end == d(12, 30))
    }

    @Test func resizeRespectsMinimumDuration() {
        let top = EntryDragCalculator.range(for: .resizeTop, original: original, translationY: 80 * 5, geometry: geometry, minimumDuration: minimum)
        #expect(top.start == d(11, 55))
        let bottom = EntryDragCalculator.range(for: .resizeBottom, original: original, translationY: -80 * 5, geometry: geometry, minimumDuration: minimum)
        #expect(bottom.end == d(10, 5))
    }
}
