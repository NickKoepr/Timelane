#if os(iOS)
import SwiftUI

/// The Timeline tab: one day with the logged-hours lane, Record/Stop and zoom in the navigation bar.
struct IOSTimelineScreen: View {
    @State private var viewModel: TimelineViewModel
    @State private var anchor = ZoomScrollAnchor()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
        _viewModel = State(initialValue: TimelineViewModel(environment: environment))
    }

    var body: some View {
        VStack(spacing: 0) {
            IOSDayBar(viewModel: viewModel)
            Divider()
            IOSTimelineScrollArea(viewModel: viewModel, anchor: anchor, changeZoom: changeZoom)
        }
        .navigationTitle("Timeline")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                RecordButton(timer: viewModel.recordingTimer) { viewModel.toggleRecording() }
            }
            ToolbarItem(placement: .topBarTrailing) { zoomMenu }
        }
        .sheet(item: Binding(get: { viewModel.form }, set: { if $0 == nil { viewModel.cancelRegistration() } })) {
            IOSTimeEntryFormSheet(viewModel: $0)
        }
        .errorAlert(Binding(get: { viewModel.entryEditing.errorMessage },
                           set: { viewModel.entryEditing.errorMessage = $0 }))
        .onChange(of: environment.requestedTimelineDay, initial: true) {
            guard let day = environment.requestedTimelineDay else { return }
            viewModel.go(to: day)
            environment.requestedTimelineDay = nil
        }
    }

    /// Pinching also zooms; this menu is the precise (and accessible) way.
    private var zoomMenu: some View {
        Menu {
            ForEach(TimelineZoom.allCases, id: \.self) { level in
                Button { changeZoom { $0.set(level) } } label: {
                    if level == viewModel.zoomState.zoom {
                        Label(level.displayName, systemImage: "checkmark")
                    } else {
                        Text(level.displayName)
                    }
                }
            }
        } label: {
            Image(systemName: "plus.magnifyingglass")
        }
        .accessibilityLabel("Timeline scale")
    }

    private func changeZoom(_ change: ZoomChange) {
        anchor.change(change, in: viewModel, animated: !reduceMotion)
    }
}

#Preview {
    NavigationStack { IOSTimelineScreen(environment: .preview()) }
}
#endif
