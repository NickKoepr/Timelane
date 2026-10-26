import SwiftUI

/// Sticky header above the scrolling timeline that explains the two lanes.
/// Positions come from `TimelineLaneLayout` for the measured width of the scroll content.
struct TimelineLaneHeader: View {
    static let height: CGFloat = 40

    /// Width of the scroll content (excludes a legacy scroll bar); 0 until measured.
    let contentWidth: CGFloat
    private let entryCaption = "Drag to register"

    var body: some View {
        GeometryReader { proxy in
            let layout = TimelineLaneLayout(totalWidth: contentWidth > 0 ? contentWidth : proxy.size.width)
            ZStack(alignment: .topLeading) {
                LaneBackdrop(layout: layout, height: Self.height)
                LaneHeaderCell(icon: "record.circle", title: "Tracked apps",
                               caption: caption("Recorded automatically", laneWidth: layout.appWidth))
                    .frame(width: layout.appWidth, height: Self.height)
                    .offset(x: layout.appX)
                LaneHeaderCell(icon: "hand.draw", title: "Your time",
                               caption: caption(entryCaption, laneWidth: layout.entryWidth))
                    .frame(width: layout.entryWidth, height: Self.height)
                    .offset(x: layout.entryX)
            }
        }
        .frame(height: Self.height)
    }

    private func caption(_ text: String, laneWidth: CGFloat) -> String? {
        TimelineLaneLayout.showsCaption(laneWidth: laneWidth) ? text : nil
    }
}

#Preview {
    TimelineLaneHeader(contentWidth: 0).frame(width: 600)
}
