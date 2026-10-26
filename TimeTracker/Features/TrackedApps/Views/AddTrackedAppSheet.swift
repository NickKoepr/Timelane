import SwiftUI

/// Pick one or more apps to track: running apps, apps seen before, or any app from disk.
struct AddTrackedAppSheet: View {
    @State var viewModel: AddTrackedAppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add apps to track").font(.headline)
            TextField("Search apps", text: $viewModel.searchText).textFieldStyle(.roundedBorder)
            list
            Button("Choose from Applications…") { viewModel.include(ApplicationOpenPanel.choose()) }
            if let message = viewModel.errorMessage {
                Text(message).font(.callout).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Cancel") { viewModel.cancel() }.keyboardShortcut(.cancelAction)
                Button("Add") { Task { await viewModel.add() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!viewModel.canAdd)
            }
        }
        .padding(20)
        .frame(width: 420, height: 480)
        .task { await viewModel.load() }
    }

    private var list: some View {
        List(viewModel.filtered, id: \.bundleIdentifier) { app in
            HStack(spacing: 10) {
                Toggle(isOn: Binding(get: { viewModel.isSelected(app) }, set: { _ in viewModel.toggle(app) })) {
                    EmptyView()
                }
                .toggleStyle(.checkbox)
                .labelsHidden()
                AppIconView(bundleIdentifier: app.bundleIdentifier)
                Text(app.name)
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture { viewModel.toggle(app) }
        }
        .overlay {
            if viewModel.filtered.isEmpty {
                Text("No apps found").foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    let environment = AppEnvironment.preview()
    return AddTrackedAppSheet(viewModel: AddTrackedAppViewModel(
        trackedApps: environment.trackedApps, appSessions: environment.appSessions,
        runningApps: RunningApps.regular, onFinish: {}))
}
