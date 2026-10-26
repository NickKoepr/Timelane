import SwiftUI

struct AppSessionLane: View {
    let blocks: [AppSessionBlockModel]
    let geometry: TimelineGeometry
    let onSelect: (AppSessionBlockModel) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            ForEach(blocks) { block in
                let frame = geometry.frame(for: block.start, end: block.end)
                AppSessionBlock(block: block, height: max(frame.height - 1, 2), onSelect: onSelect)
                    .offset(y: frame.y)
            }
        }
        .frame(height: geometry.totalHeight)
    }
}
