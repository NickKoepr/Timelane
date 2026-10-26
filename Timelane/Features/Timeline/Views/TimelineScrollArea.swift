import SwiftUI

/// The scrollable day: timeline column, empty state, zoom behaviour, delete key and initial scroll.
/// Shared by the main window and the menu bar panel. Owns the observation of the view model (`task`).
struct TimelineScrollArea: View {
    let viewModel: TimelineViewModel
    let anchor: ZoomScrollAnchor
    let changeZoom: (ZoomChange) -> Void
    /// Change this value to scroll back to the initial position (e.g. when the menu bar panel opens).
    var scrollTrigger: Int = 0

    @State private var scrollPosition = ScrollPosition(edge: .top)
    @State private var hover = TimelineHoverState()
    @FocusState private var timelineFocused: Bool

    var body: some View {
        ScrollView {
            TimelineColumn(viewModel: viewModel, hover: hover, anchor: anchor)
                .padding(.bottom, 20)
                .overlay(alignment: .top) { emptyState }
        }
        .scrollPosition($scrollPosition)
        .timelineZoom(viewModel: viewModel, scrollPosition: $scrollPosition, anchor: anchor, apply: changeZoom)
        .focusable()
        .focusEffectDisabled()
        .focused($timelineFocused)
        .onKeyPress(.delete) { deleteSelection() }
        .onKeyPress(.deleteForward) { deleteSelection() }
        .onChange(of: viewModel.entryEditing.selectedEntryId) { _, id in if id != nil { timelineFocused = true } }
        .onChange(of: scrollTrigger) { scrollToInitialPosition() }
        .task(id: viewModel.day) {
            scrollToInitialPosition()
            await viewModel.task()
        }
    }

    private func scrollToInitialPosition() {
        scrollPosition.scrollTo(y: viewModel.geometry.y(for: viewModel.initialScrollDate))
    }

    private func deleteSelection() -> KeyPress.Result {
        guard viewModel.entryEditing.selectedEntryId != nil, viewModel.form == nil else { return .ignored }
        viewModel.deleteSelectedEntry()
        return .handled
    }

    @ViewBuilder private var emptyState: some View {
        if !viewModel.hasActivity {
            Text("No activity tracked yet")
                .foregroundStyle(.secondary)
                .padding(.top, viewModel.geometry.y(for: viewModel.initialScrollDate) + 120)
                .allowsHitTesting(false)
        }
    }
}
