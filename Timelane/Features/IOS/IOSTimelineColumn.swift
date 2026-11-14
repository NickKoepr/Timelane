#if os(iOS)
import SwiftUI

/// The day on iOS: hour grid behind the single "Logged hours" lane. App sessions are not recorded on iOS, so there is no app lane.
/// Tap an empty spot to add an entry at that time, touch and hold + drag to select a range, tap an entry to edit it.
struct IOSTimelineColumn: View {
    let viewModel: TimelineViewModel
    /// Reports hovers from `TimeEntryLane`; never fed on touch screens.
    @State private var hover = TimelineHoverState()

    var body: some View {
        let geometry = viewModel.geometry
        ZStack(alignment: .topLeading) {
            HourGridView(geometry: geometry, zoom: viewModel.zoomState.zoom)
            lane(geometry: geometry)
            if viewModel.isToday { NowIndicatorView(geometry: geometry) }
        }
        .frame(maxWidth: .infinity)
        .frame(height: geometry.totalHeight)
        .coordinateSpace(name: "timeline")
    }

    /// A gesture layer behind the entries, so an entry's own tap wins over the layer.
    private func lane(geometry: TimelineGeometry) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(.entryLaneTint)
            Color.clear
                .contentShape(Rectangle())
                .gesture(SpatialTapGesture(coordinateSpace: .named("timeline")).onEnded { tap in
                    viewModel.openNewForm(for: TapSlot.range(atY: tap.location.y, geometry: geometry, zoom: viewModel.zoomState.zoom))
                })
                .gesture(IOSSelectionGesture(viewModel: viewModel))
            TimeEntryLane(viewModel: viewModel, hover: hover)
        }
        .padding(.leading, TimelineMetrics.labelWidth + TimelineMetrics.laneInset)
        .padding(.trailing, TimelineMetrics.laneInset)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Logged hours")
    }
}

#Preview {
    ScrollView { IOSTimelineColumn(viewModel: TimelineViewModel(environment: .preview())) }
}
#endif
