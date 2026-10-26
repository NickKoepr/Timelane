import SwiftUI

extension ShapeStyle where Self == Color {
    /// The subtle tint of the lane where the user registers time.
    static var entryLaneTint: Color { Color.accentColor.opacity(0.04) }
}

/// Tint behind the entry lane plus the divider between the lanes; drawn under the hour grid, never hit-tested.
struct LaneBackdrop: View {
    let layout: TimelineLaneLayout
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(.entryLaneTint)
                .frame(width: layout.entryWidth + TimelineMetrics.laneInset, height: height)
                .offset(x: layout.entryX)
            LaneDivider().frame(height: height).offset(x: layout.dividerX - 0.5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
