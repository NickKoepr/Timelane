import SwiftUI

struct ProjectFormSheet: View {
    @State var viewModel: ProjectFormViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(viewModel.isEditing ? "Edit project" : "New project")
                .font(.headline)
            TextField("Name", text: $viewModel.name)
                .textFieldStyle(.roundedBorder)
                .onSubmit(save)
            VStack(alignment: .leading, spacing: 4) {
                TextField("ID (optional)", text: $viewModel.customId)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(save)
                if viewModel.customIdTooLong {
                    Text("An ID can be at most \(ProjectCustomId.maxLength) characters.")
                        .font(.caption).foregroundStyle(.red)
                } else {
                    Text("Your own reference, e.g. a customer or order code.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            ColorPickerRow(selectedHex: $viewModel.colorHex)
            if let message = viewModel.errorMessage {
                Text(message).font(.callout).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!viewModel.canSave)
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private func save() {
        Task {
            if await viewModel.save() { dismiss() }
        }
    }
}

#Preview {
    let env = AppEnvironment.preview()
    return ProjectFormSheet(viewModel: ProjectFormViewModel(project: nil, defaultColorHex: "#4F8EF7", repository: env.projects))
}
