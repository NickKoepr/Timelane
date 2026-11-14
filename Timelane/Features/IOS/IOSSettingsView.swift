#if os(iOS)
import SwiftUI

/// The Settings tab: the iCloud setting (sync and backup, the shared settings view on its own page), the welcome tour and About.
struct IOSSettingsView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink("iCloud") { ICloudSettingsView().navigationTitle("iCloud") }
                } footer: {
                    Text("Sync and back up your projects and logged hours.")
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
