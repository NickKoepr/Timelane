import SwiftUI

/// The backup of projects and hours: what is in iCloud, Back Up Now and Restore.
struct ICloudBackupSection: View {
    @Bindable var viewModel: BackupSettingsViewModel

    var body: some View {
        Section {
            HStack(spacing: 8) {
                if viewModel.isWorking { ProgressView().controlSize(.small) }
                Text(viewModel.projectsStatusText).foregroundStyle(.secondary)
            }
            if let message = viewModel.shownError {
                Text(message).foregroundStyle(.red)
            }
            HStack {
                Button("Back Up Now") { Task { await viewModel.backUpNow() } }
                Button("Restore Backup…") { Task { await viewModel.requestRestore() } }
            }
            .disabled(viewModel.isWorking)
        } header: {
            Text("Backup")
        } footer: {
            Text("A backup is made automatically after changes, at most every 15 minutes, once this device is up to date with iCloud. Restoring replaces the projects and logged hours on all your devices.")
        }
        .confirmationDialog("Restore the backup?", isPresented: $viewModel.isConfirmingRestore,
                            presenting: viewModel.restoreCandidate) { _ in
            Button("Restore on All Devices", role: .destructive) { Task { await viewModel.confirmRestore() } }
            Button("Cancel", role: .cancel) {}
        } message: { info in
            Text("The projects and logged hours on all your devices are replaced by the backup from \(BackupSettingsViewModel.describe(info)) (\(BackupSettingsViewModel.counts(info))). App activity is not changed. A copy of the current data is kept on \(DeviceKind.current.thisDevice).")
        }
    }
}
