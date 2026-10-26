import SwiftUI

/// Sticky header above the scrolling timeline that names the two lanes.
/// Positions come from `TimelineLaneLayout` for the measured width of the scroll content.
struct TimelineLaneHeader: View {
    static let height: CGFloat = 28

    /// Width of the scroll content (excludes a legacy scroll bar); 0 until measured.
    let contentWidth: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let layout = TimelineLaneLayout(totalWidth: contentWidth > 0 ? contentWidth : proxy.size.width)
            ZStack(alignment: .topLeading) {
                LaneBackdrop(layout: layout, height: Self.height)
                LaneHeaderCell(icon: "record.circle", title: "Tracked apps")
                    .frame(width: layout.appWidth, height: Self.height)
                    .offset(x: layout.appX)
                LaneHeaderCell(icon: "hand.draw", title: "Your time")
                    .frame(width: layout.entryWidth, height: Self.height)
                    .offset(x: layout.entryX)
            }
        }
        .frame(height: Self.height)
    }
}

#Preview {
    TimelineLaneHeader(contentWidth: 0).frame(width: 600)
}
