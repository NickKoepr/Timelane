import SwiftUI

/// Modal window to register or edit a time entry (main window and menu bar panel);
/// the fields live in `TimeEntryFormContent`.
struct TimeEntryFormSheet: View {
    let viewModel: TimeEntryFormViewModel
    var width: CGFloat = 420
    var onManageProjects: (() -> Void)?

    var body: some View {
        TimeEntryFormContent(viewModel: viewModel, onManageProjects: onManageProjects)
            .padding(20)
            .frame(width: width)
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
