import SwiftUI

struct MenuBarContentView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.openWindow) private var openWindow
    @State private var viewModel: MenuBarViewModel

    init(environment: AppEnvironment) {
        _viewModel = State(initialValue: MenuBarViewModel(
            timeEntries: environment.timeEntries, appSessions: environment.appSessions,
            trackedApps: environment.trackedApps))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            statusLine
            TimelineView(.periodic(from: .now, by: 30)) { context in
                VStack(alignment: .leading, spacing: 4) {
                    totalRow("Registered today", viewModel.registeredTotal(now: context.date))
                    totalRow("Tracked today", viewModel.trackedTotal(now: context.date))
                }
            }
            Divider()
            Button("Open TimeTracker") {
                openWindow(id: "main")
                NSApp.activate()
            }
            Button("Quit TimeTracker") { NSApp.terminate(nil) }
        }
        .padding(14)
        .frame(width: 260)
        .task { await viewModel.task() }
    }

    private var statusLine: some View {
        let tracker = environment.tracker
        return HStack(spacing: 6) {
            Image(systemName: tracker.isPaused ? "pause.circle" : "record.circle")
                .foregroundStyle(tracker.isPaused ? Color.secondary : Color.red)
            Text(statusText(for: tracker))
                .lineLimit(1)
        }
    }

    private func statusText(for tracker: AppActivityTracker) -> String {
        if tracker.isPaused { return "Paused" }
        guard let app = tracker.currentApp else { return "Not tracking" }
        return tracker.isCurrentAppTracked ? app.name : "Not tracking: \(app.name)"
    }

    private func totalRow(_ title: String, _ seconds: TimeInterval) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(DurationFormatter.hoursMinutes(seconds)).monospacedDigit()
        }
    }
}

#Preview {
    let environment = AppEnvironment.preview()
    return MenuBarContentView(environment: environment).environment(environment)
}
