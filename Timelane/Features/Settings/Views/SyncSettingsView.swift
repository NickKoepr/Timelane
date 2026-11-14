import SwiftUI

struct SyncSettingsView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        SyncSettingsContent(viewModel: SyncSettingsViewModel(service: environment.sync))
    }
}

private struct SyncSettingsContent: View {
    @State var viewModel: SyncSettingsViewModel

    var body: some View {
        Form {
            Section {
                Toggle("iCloud Sync", isOn: Binding(
                    get: { viewModel.isEnabled },
                    set: { value in Task { await viewModel.setEnabled(value) } }))
                    .disabled(viewModel.isEnabling)
                Text("Keeps your projects and logged hours in step on your Macs through your private iCloud. Tracked app activity, the tracked apps list and the Record timer stay on this Mac.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                ForEach(viewModel.notices, id: \.self) { Text($0).foregroundStyle(.orange) }
                if let message = viewModel.shownError { Text(message).foregroundStyle(.red) }
            }
            if viewModel.isEnabled { statusSection }
        }
        .formStyle(.grouped)
        .confirmationDialog("iCloud already has Timelane data", isPresented: $viewModel.isChoosingExistingData) {
            Button("Replace iCloud data with this Mac") { Task { await viewModel.resolveChoice(.replaceICloud) } }
            Button("Replace this Mac's data with iCloud", role: .destructive) { Task { await viewModel.resolveChoice(.replaceLocal) } }
            Button("Cancel", role: .cancel) { Task { await viewModel.resolveChoice(.cancel) } }
        } message: {
            Text("Choose which data to keep. Replacing this Mac's data removes its local projects and logged hours; tracked app activity and the tracked apps list stay.")
        }
        .confirmationDialog("Turn off iCloud Sync?", isPresented: $viewModel.isConfirmingDisable) {
            Button("Turn Off") { Task { await viewModel.confirmDisable() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Data on this Mac and in iCloud is kept.")
        }
    }

    private var statusSection: some View {
        Section {
            HStack(spacing: 8) {
                if viewModel.isBusy { ProgressView().controlSize(.small) }
                Text(viewModel.statusText).foregroundStyle(.secondary)
            }
            Button("Sync Now") { Task { await viewModel.syncNow() } }
                .disabled(viewModel.isBusy)
        }
    }
}

#Preview {
    SyncSettingsView().environment(AppEnvironment.preview()).frame(width: 460)
}
