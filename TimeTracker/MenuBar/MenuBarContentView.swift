import SwiftUI

/// The menu bar panel: live status on top, then the same timeline as the main window.
/// The inline form covers the timeline (which stays alive underneath, keeping its scroll position).
struct MenuBarContentView: View {
    static let size = CGSize(width: 380, height: 600)

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: MenuBarViewModel
    @State private var anchor = ZoomScrollAnchor()

    init(environment: AppEnvironment) {
        _viewModel = State(initialValue: MenuBarViewModel.make(environment: environment))
    }

    private var timeline: TimelineViewModel { viewModel.timeline }

    var body: some View {
        VStack(spacing: 0) {
            MenuBarStatusLine(tracker: environment.tracker)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            Divider()
            ZStack {
                timelineLayer
                    .allowsHitTesting(timeline.form == nil)
                    .accessibilityHidden(timeline.form != nil)
                if let form = timeline.form {
                    MenuBarFormView(viewModel: form, onManageProjects: { openMainWindow(.projects) })
                }
            }
            Divider()
            MenuBarFooter(openMainWindow: { openMainWindow(nil) })
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background { PanelOpenObserver { viewModel.panelDidOpen() } }
    }

    private var timelineLayer: some View {
        VStack(spacing: 0) {
            MenuBarDayBar(viewModel: timeline, changeZoom: changeZoom)
            Divider()
            if timeline.hasNoTrackedApps { NoTrackedAppsBanner(action: { openMainWindow(.trackedApps) }) }
            if let message = timeline.entryEditing.errorMessage {
                MenuBarErrorBanner(message: message) { timeline.entryEditing.errorMessage = nil }
            }
            TimelineScrollArea(viewModel: timeline, anchor: anchor, changeZoom: changeZoom,
                               scrollTrigger: viewModel.scrollTrigger)
        }
    }

    private func changeZoom(_ change: ZoomChange) {
        anchor.change(change, in: timeline, animated: !reduceMotion)
    }

    /// Opens the main window, on a specific screen when given.
    private func openMainWindow(_ item: SidebarItem?) {
        environment.requestedSidebarItem = item
        openWindow(id: "main")
        NSApp.activate()
    }
}

#Preview {
    let environment = AppEnvironment.preview()
    return MenuBarContentView(environment: environment).environment(environment)
}
