import SwiftUI

/// The one iCloud setting: sync of projects and hours plus the backup, on the Mac's Settings window and the iOS
/// Settings tab.
struct ICloudSettingsView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        ICloudSettingsContent(
            sync: SyncSettingsViewModel(service: environment.sync, backup: environment.backup),
            backup: BackupSettingsViewModel(service: environment.backup))
    }
}

private struct ICloudSettingsContent: View {
    @State var sync: SyncSettingsViewModel
    @State var backup: BackupSettingsViewModel

    var body: some View {
        Form {
            ICloudSwitchSection(viewModel: sync, showsActivity: backup.showsActivity)
            if sync.isEnabled {
                ICloudSyncStatusSection(viewModel: sync)
                ICloudBackupSection(viewModel: backup)
            }
        }
        .formStyle(.grouped)
        .task(id: sync.isEnabled) {
            if sync.isEnabled { await backup.task() }
        }
    }
}

#Preview {
    ICloudSettingsView().environment(AppEnvironment.preview()).frame(width: 460)
}
