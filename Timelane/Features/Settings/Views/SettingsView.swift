import SwiftUI

/// Timelane ▸ Settings… (⌘,): opt-in features, each on its own tab. Backup stays first (the App Store screenshot).
struct SettingsView: View {
    var body: some View {
        TabView {
            BackupSettingsView()
                .tabItem { Label("Backup", systemImage: "icloud") }
            NotificationSettingsView()
                .tabItem { Label("Notifications", systemImage: "bell") }
        }
        .frame(width: 460)
    }
}

#Preview {
    SettingsView().environment(AppEnvironment.preview())
}
