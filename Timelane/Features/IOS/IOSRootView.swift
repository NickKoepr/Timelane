#if os(iOS)
import SwiftUI

/// Placeholder iOS shell: the shared screens in tabs, so the app launches and syncs.
/// The real touch UI (timeline gestures, forms, onboarding) comes with the iOS app.
struct IOSRootView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        TabView {
            Tab("Timeline", systemImage: "calendar.day.timeline.leading") {
                NavigationStack { TimelineScreen(environment: environment) }
            }
            Tab("Overview", systemImage: "chart.bar") {
                NavigationStack { OverviewScreen(environment: environment) }
            }
            Tab("Projects", systemImage: "folder") {
                NavigationStack { ProjectsScreen(environment: environment) }
            }
            Tab("Settings", systemImage: "gearshape") {
                IOSSettingsView()
            }
        }
        .errorAlert(Bindable(environment.timeEntryHistory).errorMessage)
    }
}

/// iCloud Sync and Backup, each on its own page.
private struct IOSSettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("iCloud Sync") { SyncSettingsView().navigationTitle("iCloud Sync") }
                NavigationLink("Backup") { BackupSettingsView().navigationTitle("Backup") }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    IOSRootView().environment(AppEnvironment.preview())
}
#endif
