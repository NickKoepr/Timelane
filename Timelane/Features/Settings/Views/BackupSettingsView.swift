import SwiftUI

struct BackupSettingsView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        BackupSettingsContent(viewModel: BackupSettingsViewModel(
            service: environment.backup, relaunch: { AppRelauncher.relaunch() }))
    }
}

private struct BackupSettingsContent: View {
    @State var viewModel: BackupSettingsViewModel

    var body: some View {
        Form {
            Section {
                Toggle("Back up to iCloud", isOn: Binding(
                    get: { viewModel.isEnabled },
                    set: { value in Task { await viewModel.setEnabled(value) } }))
                    .disabled(viewModel.isWorking)
                Text("Keeps a copy of your projects, logged hours and tracked apps in your private iCloud. Backups run automatically, at most every 15 minutes while data changes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if viewModel.isEnabled { statusSection }
        }
        .formStyle(.grouped)
        .confirmationDialog("A backup already exists in iCloud", isPresented: choiceBinding, presenting: viewModel.pendingChoice) { _ in
            Button("Restore It") { Task { await viewModel.resolveChoice(.restore) } }
            Button("Replace with This Mac's Data", role: .destructive) { Task { await viewModel.resolveChoice(.replace) } }
            Button("Cancel", role: .cancel) { Task { await viewModel.resolveChoice(.cancel) } }
        } message: { info in
            Text("From \(info.deviceName), \(info.createdAt.formatted(date: .abbreviated, time: .shortened)): \(info.projectCount) projects, \(info.timeEntryCount) time entries. Restoring replaces the data on this Mac.")
        }
        .confirmationDialog("Restore from iCloud?", isPresented: $viewModel.isConfirmingRestore, presenting: viewModel.restoreCandidate) { _ in
            Button("Restore and Restart", role: .destructive) { Task { await viewModel.confirmRestore() } }
            Button("Cancel", role: .cancel) {}
        } message: { info in
            Text("The data on this Mac is replaced by the backup from \(info.createdAt.formatted(date: .abbreviated, time: .shortened)). Timelane restarts to finish. A copy of the current data is kept on this Mac.")
        }
    }

    private var statusSection: some View {
        Section {
            HStack(spacing: 8) {
                if viewModel.isWorking { ProgressView().controlSize(.small) }
                Text(viewModel.statusText).foregroundStyle(.secondary)
            }
            if let message = viewModel.shownError {
                Text(message).foregroundStyle(.red)
            }
            HStack {
                Button("Back Up Now") { Task { await viewModel.backUpNow() } }
                Button("Restore from iCloud…") { Task { await viewModel.requestRestore() } }
            }
            .disabled(viewModel.isWorking)
            Text("Turning backup off keeps the copy that is already in iCloud.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var choiceBinding: Binding<Bool> {
        Binding(get: { viewModel.pendingChoice != nil },
                set: { if !$0 { viewModel.pendingChoice = nil } })
    }
}

#Preview {
    BackupSettingsView().environment(AppEnvironment.preview()).frame(width: 460)
}
