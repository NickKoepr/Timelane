#if os(iOS)
import SwiftUI

/// New / edit time entry as a sheet: a `Form` with Cancel / Save in the navigation bar and Delete for existing entries.
/// Uses the same `TimeEntryFormViewModel` and field views as the Mac window.
struct IOSTimeEntryFormSheet: View {
    @Bindable var viewModel: TimeEntryFormViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $viewModel.form.title, prompt: Text("What did you work on?"))
                }
                Section("Project") { ProjectSearchList(viewModel: viewModel) }
                Section { TimeEntryFormTimeFields(form: $viewModel.form) }
                Section("Note") {
                    TextField("Note", text: $viewModel.form.note, prompt: Text("Optional"), axis: .vertical)
                        .lineLimit(2...5)
                }
                messages
                if viewModel.form.isEditing {
                    Section {
                        Button("Delete Entry", role: .destructive) { Task { await viewModel.delete() } }
                            .disabled(viewModel.isBusy)
                    }
                }
            }
            .navigationTitle(viewModel.heading)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { viewModel.cancel() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await viewModel.save() } }.disabled(!viewModel.canSave)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(viewModel.isBusy)
    }

    @ViewBuilder private var messages: some View {
        if viewModel.notice != nil || viewModel.errorMessage != nil {
            Section {
                if let notice = viewModel.notice {
                    Label(notice, systemImage: "info.circle").font(.callout).foregroundStyle(.secondary)
                }
                if let message = viewModel.errorMessage {
                    Text(message).font(.callout).foregroundStyle(.red)
                }
            }
        }
    }
}

#Preview {
    let environment = AppEnvironment.preview()
    IOSTimeEntryFormSheet(viewModel: TimeEntryFormViewModel(
        form: .new(range: DateRange(start: .now.addingTimeInterval(-3600), end: .now), projectId: 1),
        projects: [Project(id: 1, name: "Website", colorHex: "#3478F6"), Project(id: 2, name: "Admin", colorHex: "#34C759")],
        projectRepository: environment.projects, editor: environment.timeEntryEditor, onFinish: { _ in }))
}
#endif
