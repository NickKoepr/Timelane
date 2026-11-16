import SwiftUI

/// Sync status and Sync Now.
struct ICloudSyncStatusSection: View {
    let viewModel: SyncSettingsViewModel

    var body: some View {
        Section("Sync") {
            HStack(spacing: 8) {
                if viewModel.isBusy { ProgressView().controlSize(.small) }
                Text(viewModel.statusText).foregroundStyle(.secondary)
            }
            Button("Sync Now") { Task { await viewModel.syncNow() } }
                .disabled(viewModel.isBusy)
        }
    }
}
