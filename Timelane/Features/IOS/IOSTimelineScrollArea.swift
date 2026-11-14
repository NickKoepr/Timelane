#if os(iOS)
import SwiftUI

/// The scrollable day: pinch to zoom (via `timelineZoom`), swipe sideways to change the day, scrolls to the working hours.
/// Owns the observation of the view model (`task`).
struct IOSTimelineScrollArea: View {
    let viewModel: TimelineViewModel
    let anchor: ZoomScrollAnchor
    let changeZoom: (ZoomChange) -> Void

    @State private var scrollPosition = ScrollPosition(edge: .top)

    var body: some View {
        ScrollView {
            IOSTimelineColumn(viewModel: viewModel)
                .padding(.bottom, 20)
                .overlay(alignment: .top) { emptyState }
        }
        .scrollPosition($scrollPosition)
        .timelineZoom(viewModel: viewModel, scrollPosition: $scrollPosition, anchor: anchor, apply: changeZoom)
        .simultaneousGesture(daySwipe)
        .task(id: viewModel.day) {
            scrollPosition.scrollTo(y: viewModel.geometry.y(for: viewModel.initialScrollDate))
            await viewModel.task()
        }
    }

    private var daySwipe: some Gesture {
        DragGesture(minimumDistance: 30).onEnded { value in
            guard viewModel.selection == nil, viewModel.form == nil else { return }
            switch DaySwipe.dayOffset(forTranslation: value.translation) {
            case 1: viewModel.goToNextDay()
            case -1: viewModel.goToPreviousDay()
            default: break
            }
        }
    }

    @ViewBuilder private var emptyState: some View {
        if !viewModel.hasActivity {
            Text("No hours logged yet.\nTap the timeline to add some.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.top, viewModel.geometry.y(for: viewModel.initialScrollDate) + 120)
                .allowsHitTesting(false)
        }
    }
}
#endif
