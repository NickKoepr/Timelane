import SwiftUI

/// Modal window to register or edit a time entry: title, project, times and note.
struct TimeEntryFormSheet: View {
    @State var viewModel: TimeEntryFormViewModel
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(viewModel.heading).font(.headline)
            TextField("Title", text: $viewModel.form.title, prompt: Text("What did you work on?"))
                .textFieldStyle(.roundedBorder)
                .focused($titleFocused)
            labeled("Project") { ProjectSearchList(viewModel: viewModel) }
            TimeEntryFormTimeFields(form: $viewModel.form)
            labeled("Note") {
                TextField("Note", text: $viewModel.form.note, prompt: Text("Optional"), axis: .vertical)
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...5)
            }
            if let message = viewModel.errorMessage {
                Text(message).font(.callout).foregroundStyle(.red)
            }
            buttons
        }
        .padding(20)
        .frame(width: 420)
        .onAppear { titleFocused = true }
        .interactiveDismissDisabled(viewModel.isBusy)
    }

    private var buttons: some View {
        HStack {
            if viewModel.form.isEditing {
                Button("Delete", role: .destructive) { Task { await viewModel.delete() } }
            }
            Spacer()
            Button("Cancel") { viewModel.cancel() }
                .keyboardShortcut(.cancelAction)
            Button("Save") { Task { await viewModel.save() } }
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.canSave)
                .background(Button("") { Task { await viewModel.save() } }
                    .keyboardShortcut(.return, modifiers: .command).opacity(0).disabled(!viewModel.canSave))
        }
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            content()
        }
    }
}

#Preview {
    TimeEntryFormSheet(viewModel: TimeEntryFormViewModel(
        form: .new(range: DateRange(start: .now.addingTimeInterval(-3600), end: .now), projectId: 1),
        projects: [Project(id: 1, name: "Website", colorHex: "#3478F6"), Project(id: 2, name: "Admin", colorHex: "#34C759")],
        projectRepository: AppEnvironment.preview().projects,
        editor: AppEnvironment.preview().timeEntryEditor, onFinish: { _ in }))
}
