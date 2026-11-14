#if os(iOS)
import SwiftUI

/// The iOS shell: Timeline, Overview, Projects and Settings in tabs, plus the first-launch welcome carousel.
struct IOSRootView: View {
    private enum Page: Hashable { case timeline, overview, projects, settings }

    @Environment(AppEnvironment.self) private var environment
    @State private var selection = Page.timeline

    var body: some View {
        TabView(selection: $selection) {
            Tab("Timeline", systemImage: "calendar.day.timeline.leading", value: Page.timeline) {
                NavigationStack { IOSTimelineScreen(environment: environment) }
            }
            Tab("Overview", systemImage: "chart.bar", value: Page.overview) {
                NavigationStack { OverviewScreen(environment: environment) }
            }
            Tab("Projects", systemImage: "folder", value: Page.projects) {
                NavigationStack { IOSProjectsScreen(environment: environment) }
            }
            Tab("Settings", systemImage: "gearshape", value: Page.settings) {
                IOSSettingsView()
            }
        }
        // A day tapped in the Overview heatmap asks for the Timeline.
        .onChange(of: environment.requestedSidebarItem) {
            guard environment.requestedSidebarItem == .timeline else { return }
            selection = .timeline
            environment.requestedSidebarItem = nil
        }
        .errorAlert(Bindable(environment.timeEntryHistory).errorMessage)
        .fullScreenCover(isPresented: Bindable(environment).isShowingOnboarding) {
            IOSOnboardingView(viewModel: environment.makeOnboardingViewModel(),
                              onClose: { environment.isShowingOnboarding = false })
        }
    }
}

#Preview {
    IOSRootView().environment(AppEnvironment.preview())
}
#endif
