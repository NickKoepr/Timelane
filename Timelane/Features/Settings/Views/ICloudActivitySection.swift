import SwiftUI

/// The app activity backup (only where app activity is recorded): its status, and taking it over from another
/// device. Restoring it is part of Restore Backup.
struct ICloudActivitySection: View {
    let viewModel: BackupSettingsViewModel

    var body: some View {
        Section {
            Text(viewModel.activityStatusText)
                .foregroundStyle(viewModel.activityNotOwned ? .orange : .secondary)
            if viewModel.activityNotOwned {
                Button("Replace with \(DeviceKind.current.thisDevice.capitalizedFirst)'s Activity") {
                    Task { await viewModel.replaceActivityBackup() }
                }
                .disabled(viewModel.isWorking)
            }
        } header: {
            Text("App Activity")
        } footer: {
            Text("App activity and the tracked apps list are backed up once an hour and restored with the backup above.")
        }
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
