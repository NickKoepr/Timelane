import SwiftUI

/// The whole day: hour grid behind an app-session lane and a time-entry lane.
struct TimelineColumn: View {
    let viewModel: TimelineViewModel
    let hover: TimelineHoverState
    let anchor: ZoomScrollAnchor

    var body: some View {
        let geometry = viewModel.geometry
        GeometryReader { proxy in
            let available = proxy.size.width - TimelineMetrics.labelWidth - TimelineMetrics.laneSpacing - TimelineMetrics.laneInset * 2
            let appWidth = available * TimelineMetrics.appLaneFraction
            ZStack(alignment: .topLeading) {
                HourGridView(geometry: geometry, zoom: viewModel.zoomState.zoom)
                lanes(geometry: geometry, appWidth: appWidth)
                if viewModel.isToday { NowIndicatorView(geometry: geometry) }
                hoverCard(columnSize: CGSize(width: proxy.size.width, height: geometry.totalHeight))
            }
        }
        .frame(height: geometry.totalHeight)
        .coordinateSpace(name: "timeline")
        .animation(.easeOut(duration: 0.1), value: hover.hovered?.id)
    }

    /// A full-size gesture layer behind both lanes: dragging anywhere selects a range.
    private func lanes(geometry: TimelineGeometry, appWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { viewModel.entryEditing.deselect() }
                .gesture(SelectionDragGesture(viewModel: viewModel))
            HStack(spacing: TimelineMetrics.laneSpacing) {
                AppSessionLane(width: appWidth, hover: hover, blocks: viewModel.sessionBlocks, geometry: geometry,
                               selectionDrag: SelectionDragGesture(viewModel: viewModel),
                               onSelect: viewModel.assign)
                    .frame(width: appWidth)
                TimeEntryLane(viewModel: viewModel, hover: hover)
            }
        }
        .padding(.leading, TimelineMetrics.labelWidth + TimelineMetrics.laneInset)
        .padding(.trailing, TimelineMetrics.laneInset)
    }

    /// Not shown while a selection or an entry drag is in progress.
    @ViewBuilder private func hoverCard(columnSize: CGSize) -> some View {
        let busy = viewModel.selection != nil || viewModel.entryEditing.preview != nil
        if let target = hover.hovered, !busy {
            TimelineHoverCard(target: target, blockFrame: hover.frame, columnSize: columnSize,
                              visibleTop: anchor.offsetY, visibleBottom: anchor.offsetY + anchor.height)
                .transition(.opacity)
        }
    }
}
