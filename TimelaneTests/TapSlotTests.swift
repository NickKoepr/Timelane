import CoreGraphics
import Foundation
import Testing
@testable import Timelane

struct TapSlotTests {
    let cal = TestCalendar.make()
    func d(_ h: Int, _ min: Int = 0) -> Date { TestCalendar.date(2026, 11, 3, h, min, calendar: cal) }

    func geometry(_ zoom: TimelineZoom) -> TimelineGeometry {
        TimelineGeometry(day: .day(of: d(12), calendar: cal), pointsPerHour: zoom.pointsPerHour)
    }

    @Test func zoomedOutGivesHalfHourSlotContainingTheTap() {
        let g = geometry(.hour)
        let y = g.y(for: d(9, 40))
        let slot = TapSlot.range(atY: y, geometry: g, zoom: .hour)
        #expect(slot.start == d(9, 30))
        #expect(slot.end == d(10))
    }

    @Test func zoomedInUsesTheZoomStep() {
        let g = geometry(.tenMinutes)
        let slot = TapSlot.range(atY: g.y(for: d(9, 47)), geometry: g, zoom: .tenMinutes)
        #expect(slot.start == d(9, 40))
        #expect(slot.end == d(9, 50))
        let quarter = geometry(.quarterHour)
        let q = TapSlot.range(atY: quarter.y(for: d(9, 47)), geometry: quarter, zoom: .quarterHour)
        #expect(q.start == d(9, 45))
        #expect(q.end == d(10))
    }

    @Test func tapsOutsideTheDayStayInsideIt() {
        let g = geometry(.hour)
        let first = TapSlot.range(atY: -40, geometry: g, zoom: .hour)
        #expect(first.start == g.day.start)
        #expect(first.duration == 30 * 60)
        let last = TapSlot.range(atY: g.totalHeight + 100, geometry: g, zoom: .hour)
        #expect(last.end == g.day.end)
        #expect(last.duration == 30 * 60)
    }

    @Test func everyZoomLevelHasASlotLength() {
        for zoom in TimelineZoom.allCases { #expect(zoom.tapSlotMinutes > 0) }
    }
}

struct DaySwipeTests {
    @Test func horizontalSwipesChangeTheDay() {
        #expect(DaySwipe.dayOffset(forTranslation: CGSize(width: -120, height: 10)) == 1)
        #expect(DaySwipe.dayOffset(forTranslation: CGSize(width: 120, height: -10)) == -1)
    }

    @Test func shortOrDiagonalDragsAreIgnored() {
        #expect(DaySwipe.dayOffset(forTranslation: CGSize(width: -40, height: 0)) == 0)
        #expect(DaySwipe.dayOffset(forTranslation: CGSize(width: -120, height: 100)) == 0)
        #expect(DaySwipe.dayOffset(forTranslation: CGSize(width: 5, height: 300)) == 0)
    }
}
