import SwiftUI

struct TrackedAppsScreen: View {
    @State private var viewModel: TrackedAppsViewModel
    @State private var showingAdd = false
    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
        _viewModel = State(initialValue: TrackedAppsViewModel(repository: environment.trackedApps))
    }

    var body: some View {
        content
            .toolbar {
                ToolbarItem {
                    Button { showingAdd = true } label: { Label("Add App", systemImage: "plus") }
                        .keyboardShortcut("n", modifiers: .command)
                }
            }
            .task { await viewModel.task() }
            .sheet(isPresented: $showingAdd) {
                AddTrackedAppSheet(viewModel: AddTrackedAppViewModel(
                    trackedApps: environment.trackedApps, appSessions: environment.appSessions,
                    runningApps: RunningApps.regular, onFinish: { showingAdd = false }))
            }
            .errorAlert($viewModel.errorMessage)
            .navigationTitle("Tracked Apps")
    }

    @ViewBuilder private var content: some View {
        if viewModel.apps.isEmpty {
            ContentUnavailableView("No apps tracked", systemImage: "app.badge.checkmark",
                                   description: Text("Add the apps you work in, e.g. Xcode, Terminal, your browser."))
        } else {
            List(viewModel.apps, selection: $viewModel.selectedId) { app in
                TrackedAppRow(app: app) { Task { await viewModel.remove(app) } }
                    .tag(app.id)
                    .contextMenu { Button("Remove") { Task { await viewModel.remove(app) } } }
            }
            .onDeleteCommand { Task { await viewModel.removeSelected() } }
        }
    }
}

#Preview {
    TrackedAppsScreen(environment: .preview()).frame(width: 600, height: 400)
}
