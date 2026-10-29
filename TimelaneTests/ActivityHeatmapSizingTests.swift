import Testing
import CoreGraphics
@testable import Timelane

struct ActivityHeatmapSizingTests {
    private func sizing(_ width: CGFloat, columns: Int = 53) -> ActivityHeatmapSizing {
        ActivityHeatmapSizing(availableWidth: width, columnCount: columns, labelWidth: 32, spacing: 2,
                              cellRange: 9...16)
    }

    private func expect(_ result: ActivityHeatmapSizing, cell: CGFloat, scrolls: Bool,
                        sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(result.cell == cell, sourceLocation: sourceLocation)
        #expect(result.scrolls == scrolls, sourceLocation: sourceLocation)
    }

    @Test func wideWidthClampsToMaximum() {
        expect(sizing(2000), cell: 16, scrolls: false)
    }

    @Test func widthInRangeFillsExactly() {
        expect(sizing(32 + 53 * 14), cell: 12, scrolls: false)
    }

    @Test func thresholdWidthStillFits() {
        expect(sizing(32 + 53 * 11), cell: 9, scrolls: false)
    }

    @Test func belowThresholdScrolls() {
        expect(sizing(614), cell: 9, scrolls: true)
        expect(sizing(448), cell: 9, scrolls: true)
    }

    @Test func degenerateInputsScrollWithoutNaN() {
        expect(sizing(0), cell: 9, scrolls: true)
        expect(sizing(-5), cell: 9, scrolls: true)
        expect(sizing(800, columns: 0), cell: 9, scrolls: true)
    }

    @Test func legendEndsUnderLastSquaresWhenWide() {
        let wide = sizing(2000)
        #expect(wide.contentWidth == CGFloat(32 + 53 * 18 - 2))
        #expect(wide.visibleTrailing(in: 2000) == wide.contentWidth)
    }

    @Test func legendEndsAtEdgeWhileScrolling() {
        let narrow = sizing(448)
        #expect(narrow.contentWidth > 448)
        #expect(narrow.visibleTrailing(in: 448) == 448)
    }

    @Test func resultOnlyDependsOnWidth() {
        let first = sizing(774)
        _ = sizing(448)
        #expect(sizing(774) == first)
    }
}
