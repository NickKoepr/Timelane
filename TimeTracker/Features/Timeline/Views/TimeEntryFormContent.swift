import SwiftUI

/// Fields and buttons to register or edit a time entry: title, project, times and note.
/// Layout (padding, width) is left to the host: a sheet in the main window, inline in the menu bar panel.
struct TimeEntryFormContent: View {
    @Bindable var viewModel: TimeEntryFormViewModel
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
        .onAppear { titleFocused = true }
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
