#if os(iOS)
import SwiftUI

/// The Settings tab: iCloud Sync and Backup (rows "Sync" / "Backup" under the iCloud header) (the shared settings views, each on its own page), the welcome tour and About.
struct IOSSettingsView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        NavigationStack {
            List {
                Section("iCloud") {
                    NavigationLink("Sync") { SyncSettingsView().navigationTitle("Sync") }   // the section already says iCloud
                    NavigationLink("Backup") { BackupSettingsView().navigationTitle("Backup") }
                }
                Section {
                    Button("Welcome to Timelane") { environment.showOnboarding() }
                }
                Section("About") {
                    LabeledContent("Version", value: AppVersion.current)
                    ForEach(AboutLinks.all, id: \.title) { link in
                        Link(link.title, destination: link.url)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)   // same compact bar as the other tabs
        }
    }
}

#Preview {
    IOSSettingsView().environment(AppEnvironment.preview())
}
#endif
