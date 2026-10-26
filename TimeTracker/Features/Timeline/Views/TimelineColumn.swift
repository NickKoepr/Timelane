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
                HStack(spacing: TimelineMetrics.laneSpacing) {
                    AppSessionLane(blocks: viewModel.sessionBlocks, geometry: geometry, onSelect: viewModel.assign)
                        .frame(width: appWidth)
                    TimeEntryLane(viewModel: viewModel)
                }
                .padding(.leading, TimelineMetrics.labelWidth + TimelineMetrics.laneInset)
                .padding(.trailing, TimelineMetrics.laneInset)
                if viewModel.isToday { NowIndicatorView(geometry: geometry) }
            }
        }
        .frame(height: geometry.totalHeight)
        .coordinateSpace(name: "timeline")
    }
}
