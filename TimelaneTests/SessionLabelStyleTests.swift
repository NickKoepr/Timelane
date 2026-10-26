import CoreGraphics
import Testing
@testable import Timelane

struct SessionLabelStyleTests {
    @Test func heightBoundaries() {
        func style(_ h: CGFloat) -> SessionLabelStyle { .style(forHeight: h, width: 200) }
        #expect(style(40) == .full)
        #expect(style(32) == .full)
        #expect(style(31.9) == .singleLine)
        #expect(style(15) == .singleLine)
        #expect(style(14.9) == .iconOnly)
        #expect(style(10) == .iconOnly)
        #expect(style(9.9) == .colorOnly)
        #expect(style(2) == .colorOnly)
    }

    @Test func narrowLanesDropTheName() {
        #expect(SessionLabelStyle.style(forHeight: 50, width: 60) == .full)
        #expect(SessionLabelStyle.style(forHeight: 50, width: 59) == .iconOnly)
        #expect(SessionLabelStyle.style(forHeight: 50, width: 24) == .iconOnly)
        #expect(SessionLabelStyle.style(forHeight: 50, width: 23) == .colorOnly)
    }

    @Test func twoMinutesShowTheNameWhenZoomedIn() {
        let height = TimelineZoom.tenMinutes.pointsPerHour / 30 - 1   // 2 minutes
        #expect(SessionLabelStyle.style(forHeight: height, width: 200) == .singleLine)
        let overview = TimelineZoom.hour.pointsPerHour / 6 - 1         // 10 minutes at 1 h
        #expect(SessionLabelStyle.style(forHeight: overview, width: 200) == .iconOnly)
    }
}
