import SwiftUI

/// The iCloud switch, what it does, and the dialogs for turning it on and off.
struct ICloudSwitchSection: View {
    @Bindable var viewModel: SyncSettingsViewModel
    let showsActivity: Bool
    private var device: DeviceKind { .current }

    var body: some View {
        Section {
            Toggle("iCloud Sync & Backup", isOn: Binding(
                get: { viewModel.isEnabled },
                set: { value in Task { await viewModel.setEnabled(value) } }))
                .disabled(viewModel.isEnabling)
            Text(explanation)
                .font(.footnote)
                .foregroundStyle(.secondary)
            ForEach(viewModel.notices, id: \.self) { Text($0).foregroundStyle(.orange) }
            if let message = viewModel.shownError { Text(message).foregroundStyle(.red) }
        }
        .confirmationDialog("iCloud already has Timelane data", isPresented: $viewModel.isChoosingExistingData) {
            Button("Replace iCloud data with \(device.thisDevice)") { Task { await viewModel.resolveChoice(.replaceICloud) } }
            Button("Replace \(device.thisDevice)'s data with iCloud", role: .destructive) { Task { await viewModel.resolveChoice(.replaceLocal) } }
            Button("Cancel", role: .cancel) { Task { await viewModel.resolveChoice(.cancel) } }
        } message: {
            Text("Choose which data to keep. Replacing \(device.thisDevice)'s data removes its local projects and logged hours; tracked app activity and the tracked apps list stay.")
        }
        .confirmationDialog("A backup exists in iCloud", isPresented: offerBinding, presenting: viewModel.backupOffer) { _ in
            Button("Restore Backup") { Task { await viewModel.resolveBackupOffer(.restore) } }
            Button("Use \(device.thisDevice)'s Data", role: .destructive) { Task { await viewModel.resolveBackupOffer(.replace) } }
            Button("Cancel", role: .cancel) { Task { await viewModel.resolveBackupOffer(.cancel) } }
        } message: { info in
            Text("From \(BackupSettingsViewModel.describe(info)): \(BackupSettingsViewModel.counts(info)). Restoring replaces the projects and logged hours on \(device.thisDevice); using \(device.thisDevice)'s data replaces the backup later.")
        }
        .confirmationDialog("Turn off iCloud?", isPresented: $viewModel.isConfirmingDisable) {
            Button("Turn Off") { Task { await viewModel.confirmDisable() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Syncing and backups stop. The data on \(device.thisDevice) and in iCloud is kept.")
        }
    }

    private var explanation: String {
        var text = "Keeps your projects and logged hours the same on all your devices, with a backup in your private "
            + "iCloud that you can go back to."
        if showsActivity {
            text += " App activity and the tracked apps list are not synced: they stay on \(device.thisDevice), but are part of the backup."
        }
        return text + " The Record timer stays on \(device.thisDevice)."
    }

    private var offerBinding: Binding<Bool> {
        Binding(get: { viewModel.backupOffer != nil },
                set: { if !$0 { viewModel.backupOffer = nil } })
    }
}
