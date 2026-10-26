import CoreGraphics
import Foundation
import Testing
@testable import TimeTracker

@MainActor
struct TimelineZoomAnchorTests {
    let cal = TestCalendar.make()
    func d(_ h: Int, _ m: Int = 0) -> Date { TestCalendar.date(2026, 11, 3, h, m, calendar: cal) }
    func geometry(_ zoom: TimelineZoom) -> TimelineGeometry {
        TimelineGeometry(day: .day(of: d(12), calendar: cal), pointsPerHour: zoom.pointsPerHour)
    }

    @Test func centerStaysCenteredAfterZoom() {
        let old = geometry(.hour)
        let center = TimelineZoomAnchor.centerDate(offset: 800, height: 400, geometry: old)  // y 1000 = 12:30
        #expect(center == d(12, 30))
        let offset = TimelineZoomAnchor.offset(keeping: center, centeredIn: 400, geometry: geometry(.tenMinutes))
        #expect(offset == 12.5 * 480 - 200)
    }

    @Test func offsetIsNeverNegative() {
        #expect(TimelineZoomAnchor.offset(keeping: d(0, 10), centeredIn: 600, geometry: geometry(.hour)) == 0)
    }

    @Test func anchorCapturesBeforeAndAppliesAfter() {
        let anchor = ZoomScrollAnchor()
        anchor.visibleAreaChanged(offsetY: 800, height: 400)
        #expect(anchor.takeOffset(with: geometry(.halfHour)) == nil)
        anchor.capture(with: geometry(.hour))
        #expect(anchor.takeOffset(with: geometry(.halfHour)) == 12.5 * 160 - 200)
        #expect(anchor.takeOffset(with: geometry(.halfHour)) == nil)
    }

    @Test func pinchStepsOneLevelPerThreshold() {
        var stepper = PinchZoomStepper()
        #expect(stepper.step(for: 1.1) == 0)
        #expect(stepper.step(for: 1.26) == 1)
        #expect(stepper.step(for: 1.4) == 0)        // only 11% more than last step
        #expect(stepper.step(for: 1.6) == 1)
        #expect(stepper.step(for: 1.1) == -1)
        stepper.reset()
        #expect(stepper.step(for: 0.7) == -1)
    }

    @Test func dragCalculatorWorksAtOtherScales() {
        let g = geometry(.tenMinutes)   // 8 pt per minute
        let original = DateRange(start: d(10), end: d(11))
        let moved = EntryDragCalculator.range(for: .move, original: original, translationY: 8 * 30 + 3, geometry: g, minimumDuration: 300)
        #expect(moved.start == d(10, 30))
        let resized = EntryDragCalculator.range(for: .resizeBottom, original: original, translationY: -8 * 58, geometry: g, minimumDuration: 300)
        #expect(resized.end == d(10, 5))
    }
}
