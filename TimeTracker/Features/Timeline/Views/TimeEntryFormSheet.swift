import SwiftUI

/// Modal window to register or edit a time entry (main window); the fields live in `TimeEntryFormContent`.
struct TimeEntryFormSheet: View {
    let viewModel: TimeEntryFormViewModel

    var body: some View {
        TimeEntryFormContent(viewModel: viewModel)
            .padding(20)
            .frame(width: 420)
            .interactiveDismissDisabled(viewModel.isBusy)
    }
}

#Preview {
    TimeEntryFormSheet(viewModel: TimeEntryFormViewModel(
        form: .new(range: DateRange(start: .now.addingTimeInterval(-3600), end: .now), projectId: 1),
        projects: [Project(id: 1, name: "Website", colorHex: "#3478F6"), Project(id: 2, name: "Admin", colorHex: "#34C759")],
        projectRepository: AppEnvironment.preview().projects,
        editor: AppEnvironment.preview().timeEntryEditor, onFinish: { _ in }))
}
