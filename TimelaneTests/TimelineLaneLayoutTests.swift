import Testing
import CoreGraphics
@testable import Timelane

struct TimelineLaneLayoutTests {
    @Test(arguments: [380, 480, 900] as [CGFloat])
    func lanesDoNotOverlapAndFillTheWidth(width: CGFloat) {
        let l = TimelineLaneLayout(totalWidth: width)
        #expect(l.appX + l.appWidth + TimelineMetrics.laneSpacing == l.entryX)
        #expect(l.entryX + l.entryWidth + TimelineMetrics.laneInset == width)
        #expect(l.dividerX > l.appX + l.appWidth && l.dividerX < l.entryX)
        #expect(l.dividerX == l.appX + l.appWidth + TimelineMetrics.laneSpacing / 2)
        #expect(l.appWidth > 0 && l.entryWidth > l.appWidth)
    }

    @Test func appLaneIsFortyPercent() {
        let l = TimelineLaneLayout(totalWidth: 900)
        #expect(abs(l.appWidth / l.availableWidth - TimelineMetrics.appLaneFraction) < 0.0001)
    }

    @Test func tinyWidthNeverGoesNegative() {
        let l = TimelineLaneLayout(totalWidth: 10)
        #expect(l.appWidth == 0 && l.entryWidth == 0)
    }
}
