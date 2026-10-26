import SwiftUI

struct TimelineScreen: View {
    @State private var viewModel: TimelineViewModel
    @State private var scrollPosition = ScrollPosition(edge: .top)
    @State private var anchor = ZoomScrollAnchor()
    @State private var hover = TimelineHoverState()
    @FocusState private var timelineFocused: Bool

    private let onShowTrackedApps: () -> Void

    init(environment: AppEnvironment, onShowTrackedApps: @escaping () -> Void = {}) {
        self.onShowTrackedApps = onShowTrackedApps
        _viewModel = State(initialValue: TimelineViewModel(
            timeEntries: environment.timeEntries,
            appSessions: environment.appSessions,
            projects: environment.projects,
            trackedApps: environment.trackedApps,
            editor: environment.timeEntryEditor))
    }

    var body: some View {
        VStack(spacing: 0) {
            DayNavigationBar(viewModel: viewModel, changeZoom: changeZoom)
            Divider()
            if viewModel.hasNoTrackedApps { NoTrackedAppsBanner(action: onShowTrackedApps) }
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
        }
        .task(id: viewModel.day) {
            scrollPosition.scrollTo(y: viewModel.geometry.y(for: viewModel.initialScrollDate))
            await viewModel.task()
        }
        .sheet(item: Binding(get: { viewModel.form }, set: { if $0 == nil { viewModel.cancelRegistration() } })) {
            TimeEntryFormSheet(viewModel: $0)
        }
        .errorAlert(Binding(get: { viewModel.entryEditing.errorMessage },
                           set: { viewModel.entryEditing.errorMessage = $0 }))
        .navigationTitle("Timeline")
    }

    /// Applies a zoom change and keeps the time in the middle of the view in place.
    private func changeZoom(_ change: ZoomChange) {
        anchor.capture(with: viewModel.geometry)
        change(viewModel.zoomState)
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

#Preview {
    TimelineScreen(environment: .preview()).frame(width: 800, height: 600)
}
