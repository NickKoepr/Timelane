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
            case .timeline: Text("Timeline")
            case .projects: ProjectsScreen(environment: environment)
            }
        }
    }
}

#Preview {
    RootView().environment(AppEnvironment.preview())
}
