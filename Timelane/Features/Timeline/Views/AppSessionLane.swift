import SwiftUI

struct AppSessionLane: View {
    let width: CGFloat
    let hover: TimelineHoverState
    let blocks: [AppSessionBlockModel]
    let geometry: TimelineGeometry
    let selectionDrag: SelectionDragGesture
    let onSelect: (AppSessionBlockModel) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            ForEach(blocks) { block in
                let frame = geometry.frame(for: block.start, end: block.end)
                AppSessionBlock(block: block, height: max(frame.height - 1, 2), width: width,
                                selectionDrag: selectionDrag, onSelect: onSelect)
                    .reportsHover(.session(block), to: hover, y: frame.y, height: max(frame.height - 1, 2))
                    .offset(y: frame.y)
            }
        }
        .frame(height: geometry.totalHeight)
    }
}
