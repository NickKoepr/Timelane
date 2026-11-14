import SwiftUI

/// The app activity backup (only where app activity is recorded): status, restore and taking it over.
struct ICloudActivitySection: View {
    @Bindable var viewModel: BackupSettingsViewModel

    var body: some View {
        Section {
            Text(viewModel.activityStatusText)
                .foregroundStyle(viewModel.activityNotOwned ? .orange : .secondary)
            if let message = viewModel.activityRestoreMessage {
                Text(message).foregroundStyle(.secondary)
            }
            HStack {
                Button("Restore App Activity…") { Task { await viewModel.requestActivityRestore() } }
                if viewModel.activityNotOwned {
                    Button("Replace with \(DeviceKind.current.thisDevice.capitalizedFirst)'s Activity") {
                        Task { await viewModel.replaceActivityBackup() }
                    }
                }
            }
            .disabled(viewModel.isWorking)
        } header: {
            Text("App Activity")
        } footer: {
            Text("Backed up once an hour. Restoring adds the app activity and tracked apps \(DeviceKind.current.thisDevice) is missing; nothing is removed.")
        }
        .confirmationDialog("Restore app activity?", isPresented: $viewModel.isConfirmingActivityRestore,
                            presenting: viewModel.activityCandidate) { _ in
            Button("Restore") { Task { await viewModel.confirmActivityRestore() } }
            Button("Cancel", role: .cancel) {}
        } message: { info in
            Text("Adds the app activity from the backup of \(BackupSettingsViewModel.describe(info)) that is missing on \(DeviceKind.current.thisDevice). Afterwards this backup is replaced by the activity of \(DeviceKind.current.thisDevice).")
        }
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
