import SwiftUI

struct TimelineScreen: View {
    @State private var viewModel: TimelineViewModel
    @State private var anchor = ZoomScrollAnchor()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let environment: AppEnvironment
    private let onShowTrackedApps: () -> Void

    init(environment: AppEnvironment, onShowTrackedApps: @escaping () -> Void = {}) {
        self.environment = environment
        self.onShowTrackedApps = onShowTrackedApps
        _viewModel = State(initialValue: TimelineViewModel(
            timeEntries: environment.timeEntries,
            appSessions: environment.appSessions,
            projects: environment.projects,
            trackedApps: environment.trackedApps,
            editor: environment.timeEntryEditor,
            recordingTimer: environment.recordingTimer,
            liveAutoEntry: environment.liveAutoEntry))
    }

    var body: some View {
        VStack(spacing: 0) {
            DayNavigationBar(viewModel: viewModel, changeZoom: changeZoom)
            Divider()
            if viewModel.hasNoTrackedApps { NoTrackedAppsBanner(action: onShowTrackedApps) }
            TimelineScrollArea(viewModel: viewModel, anchor: anchor, changeZoom: changeZoom)
        }
        .sheet(item: Binding(get: { viewModel.form }, set: { if $0 == nil { viewModel.cancelRegistration() } })) {
            TimeEntryFormSheet(viewModel: $0)
        }
        .errorAlert(Binding(get: { viewModel.entryEditing.errorMessage },
                           set: { viewModel.entryEditing.errorMessage = $0 }))
        .navigationTitle("Timeline")
        .onChange(of: environment.requestedTimelineDay, initial: true) {
            guard let day = environment.requestedTimelineDay else { return }
            viewModel.go(to: day)
            environment.requestedTimelineDay = nil
        }
    }

    private func changeZoom(_ change: ZoomChange) {
        anchor.change(change, in: viewModel, animated: !reduceMotion)
    }
}

#Preview {
    TimelineScreen(environment: .preview()).frame(width: 800, height: 600)
}
