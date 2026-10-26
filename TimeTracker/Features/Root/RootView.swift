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
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            switch selection ?? .timeline {
            case .timeline: TimelineScreen(environment: environment, onShowTrackedApps: { selection = .trackedApps })
            case .projects: ProjectsScreen(environment: environment)
            case .trackedApps: TrackedAppsScreen(environment: environment)
            }
        }
        .background { sidebarShortcuts }
    }

    /// ⌘1 / ⌘2 / ⌘3 switch screens.
    private var sidebarShortcuts: some View {
        HStack {
            Button("Timeline") { selection = .timeline }.keyboardShortcut("1", modifiers: .command)
            Button("Projects") { selection = .projects }.keyboardShortcut("2", modifiers: .command)
            Button("Tracked Apps") { selection = .trackedApps }.keyboardShortcut("3", modifiers: .command)
        }
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview {
    RootView().environment(AppEnvironment.preview())
}
