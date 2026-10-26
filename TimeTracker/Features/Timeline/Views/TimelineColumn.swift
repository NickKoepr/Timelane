import SwiftUI

/// The whole day: hour grid behind an app-session lane and a time-entry lane.
struct TimelineColumn: View {
    let viewModel: TimelineViewModel

    var body: some View {
        let geometry = viewModel.geometry
        GeometryReader { proxy in
            let available = proxy.size.width - TimelineMetrics.labelWidth - TimelineMetrics.laneSpacing - TimelineMetrics.laneInset * 2
            let appWidth = available * TimelineMetrics.appLaneFraction
            ZStack(alignment: .topLeading) {
                HourGridView(geometry: geometry)
                lanes(geometry: geometry, appWidth: appWidth)
                if viewModel.isToday { NowIndicatorView(geometry: geometry) }
            }
        }
        .frame(height: geometry.totalHeight)
        .coordinateSpace(name: "timeline")
    }

    /// A full-size gesture layer behind both lanes: dragging anywhere selects a range.
    private func lanes(geometry: TimelineGeometry, appWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { viewModel.entryEditing.deselect() }
                .gesture(SelectionDragGesture(viewModel: viewModel))
            HStack(spacing: TimelineMetrics.laneSpacing) {
                AppSessionLane(blocks: viewModel.sessionBlocks, geometry: geometry,
                               selectionDrag: SelectionDragGesture(viewModel: viewModel),
                               onSelect: viewModel.assign)
                    .frame(width: appWidth)
                TimeEntryLane(viewModel: viewModel)
            }
        }
        .padding(.leading, TimelineMetrics.labelWidth + TimelineMetrics.laneInset)
        .padding(.trailing, TimelineMetrics.laneInset)
    }
}
