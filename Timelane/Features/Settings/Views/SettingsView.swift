#if os(macOS)
import SwiftUI

/// Timelane ▸ Settings… (⌘,). iCloud Sync first, then backup.
struct SettingsView: View {
    var body: some View {
        TabView {
            SyncSettingsView()
                .tabItem { Label("Sync", systemImage: "arrow.triangle.2.circlepath.icloud") }
            BackupSettingsView()
                .tabItem { Label("Backup", systemImage: "icloud") }
        }
        .frame(width: 460)
    }
}

#Preview {
    SettingsView().environment(AppEnvironment.preview())
}
#endif
