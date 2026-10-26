import Foundation
import Testing
@testable import TimeTracker

struct TimelineSelectionTests {
    func d(_ h: Int, _ m: Int = 0) -> Date { TestCalendar.date(2026, 11, 3, h, m) }

    @Test func normalizesUpwardDrags() {
        let selection = TimelineSelection(anchor: d(13), current: d(10))
        #expect(selection.start == d(10))
        #expect(selection.end == d(13))
        #expect(selection.duration == 3 * 3600)
    }

    @Test func labelShowsRangeAndDuration() {
        let label = TimelineSelection(anchor: d(10), current: d(13)).label
        #expect(label.hasSuffix("(3:00)"))
    }
}
