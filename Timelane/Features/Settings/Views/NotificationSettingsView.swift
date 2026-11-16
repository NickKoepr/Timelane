import SwiftUI

struct NotificationSettingsView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        NotificationSettingsContent(viewModel: NotificationSettingsViewModel(service: environment.reminders))
    }
}

private struct NotificationSettingsContent: View {
    @State var viewModel: NotificationSettingsViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section {
                Toggle("Remind me to log my hours", isOn: Binding(
                    get: { viewModel.isEnabled },
                    set: { value in Task { await viewModel.setEnabled(value) } }))
                Text("Shows a notification on the days you choose, at the time you set for each day. Click it to open today's timeline.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let message = viewModel.errorMessage {
                    Text(message).foregroundStyle(.red)
                }
            }
            if let message = viewModel.permissionMessage { permissionSection(message) }
            if viewModel.isEnabled { daysSection }
        }
        .formStyle(.grouped)
        .task { await viewModel.refresh() }
    }

    private func permissionSection(_ message: String) -> some View {
        Section {
            Label {
                Text(message)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
            }
            Button("Open System Settings…") {
                if let url = viewModel.systemSettingsURL { openURL(url) }
            }
        }
    }

    private var daysSection: some View {
        Section("Days") {
            ForEach(viewModel.weekdays, id: \.self) { weekday in
                ReminderDayRow(
                    name: viewModel.name(of: weekday),
                    isOn: Binding(get: { viewModel.isOn(weekday) }, set: { viewModel.setOn($0, for: weekday) }),
                    time: Binding(get: { viewModel.time(for: weekday) }, set: { viewModel.setTime($0, for: weekday) }))
            }
            Text(viewModel.scheduleSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NotificationSettingsView().environment(AppEnvironment.preview()).frame(width: 460)
}
