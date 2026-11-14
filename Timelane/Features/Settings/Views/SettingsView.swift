#if os(macOS)
import SwiftUI

/// Timelane ▸ Settings… (⌘,): the iCloud setting (sync and backup are one feature).
struct SettingsView: View {
    var body: some View {
        ICloudSettingsView()
            .frame(width: 460)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    SettingsView().environment(AppEnvironment.preview())
}
#endif
