import SwiftUI

/// The hints of the empty lanes, placed near `y` (the visible part of the day).
struct LaneEmptyHints: View {
    let layout: TimelineLaneLayout
    let y: CGFloat
    let showsAppHint: Bool
    let showsEntryHint: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if showsAppHint {
                LaneEmptyHint(icon: "record.circle", text: "Apps you use appear here")
                    .frame(width: layout.appWidth).offset(x: layout.appX, y: y)
            }
            if showsEntryHint {
                LaneEmptyHint(icon: "hand.draw", text: "Drag here to register time")
                    .frame(width: layout.entryWidth).offset(x: layout.entryX, y: y)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}
