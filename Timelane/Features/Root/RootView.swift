import SwiftUI

struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var selection: SidebarItem? = .timeline

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.title, systemImage: item.systemImage)
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: WindowMetrics.sidebarMinimumWidth, ideal: 180)
        } detail: {
            detail.navigationSplitViewColumnWidth(min: WindowMetrics.detailMinimumWidth, ideal: 720)
        }
        .frame(minWidth: WindowMetrics.minimumSize.width, minHeight: WindowMetrics.minimumSize.height)
        .background { sidebarShortcuts }
        .background { TimeEntryUndoShortcuts(history: environment.timeEntryHistory) }
        .errorAlert(Bindable(environment.timeEntryHistory).errorMessage)
        .onChange(of: environment.requestedSidebarItem, initial: true) {
            guard let item = environment.requestedSidebarItem else { return }
            selection = item
            environment.requestedSidebarItem = nil
        }
    }

    @ViewBuilder private var detail: some View {
        switch selection ?? .timeline {
        case .timeline: TimelineScreen(environment: environment, onShowTrackedApps: { selection = .trackedApps })
        case .projects: ProjectsScreen(environment: environment)
        case .trackedApps: TrackedAppsScreen(environment: environment)
        case .overview: OverviewScreen(environment: environment)
        }
    }

    /// ⌘1 – ⌘4 switch screens.
    private var sidebarShortcuts: some View {
        HStack {
            Button("Timeline") { selection = .timeline }.keyboardShortcut("1", modifiers: .command)
            Button("Projects") { selection = .projects }.keyboardShortcut("2", modifiers: .command)
            Button("Tracked Apps") { selection = .trackedApps }.keyboardShortcut("3", modifiers: .command)
            Button("Overview") { selection = .overview }.keyboardShortcut("4", modifiers: .command)
        }
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview {
    RootView().environment(AppEnvironment.preview())
}
