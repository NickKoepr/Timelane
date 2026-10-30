import SwiftUI

/// Timelane ▸ Settings… (⌘,). One tab for now; room for more settings later.
struct SettingsView: View {
    var body: some View {
        TabView {
            BackupSettingsView()
                .tabItem { Label("Backup", systemImage: "icloud") }
        }
        .frame(width: 460)
    }
}

#Preview {
    SettingsView().environment(AppEnvironment.preview())
}
