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
        if !viewModel.isLoaded {
            Color.clear
        } else if viewModel.apps.isEmpty {
            ContentUnavailableView {
                Label("No apps tracked", systemImage: "app.badge.checkmark")
            } description: {
                Text("Add the apps you work in, e.g. Xcode, Terminal, your browser.")
            } actions: {
                Button("Add App") { showingAdd = true }
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(viewModel.apps, selection: $viewModel.selectedId) { app in
                TrackedAppRow(app: app) { Task { await viewModel.remove(app) } }
                    .tag(app.id)
                    .contextMenu { Button("Remove") { Task { await viewModel.remove(app) } } }
            }
            .onDeleteCommand { Task { await viewModel.removeSelected() } }
            .safeAreaInset(edge: .bottom) {
                Text("Only these apps are recorded. Removing an app stops recording it; time already recorded stays on the timeline.")
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(3).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
            }
        }
    }
}

#Preview {
    TrackedAppsScreen(environment: .preview()).frame(width: 600, height: 400)
}

#Preview("Empty") {
    TrackedAppsScreen(environment: .inMemory()).frame(width: 800, height: 600)
}
