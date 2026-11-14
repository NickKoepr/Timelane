#if os(iOS)
import SwiftUI

/// New / edit project as a sheet; the same `ProjectFormViewModel` as the Mac sheet.
struct IOSProjectFormSheet: View {
    @State var viewModel: ProjectFormViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $viewModel.name)
                        .submitLabel(.done)
                        .onSubmit(save)
                }
                Section {
                    TextField("ID (optional)", text: $viewModel.customId)
                        .textInputAutocapitalization(.never)
                } footer: {
                    if viewModel.customIdTooLong {
                        Text("An ID can be at most \(ProjectCustomId.maxLength) characters.").foregroundStyle(.red)
                    } else {
                        Text("Your own reference, e.g. a customer or order code.")
                    }
                }
                Section("Color") {
                    ScrollView(.horizontal, showsIndicators: false) { ColorPickerRow(selectedHex: $viewModel.colorHex) }
                }
                if let message = viewModel.errorMessage {
                    Section { Text(message).foregroundStyle(.red) }
                }
            }
            .navigationTitle(viewModel.isEditing ? "Edit project" : "New project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!viewModel.canSave)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        Task { if await viewModel.save() { dismiss() } }
    }
}

#Preview {
    let env = AppEnvironment.preview()
    IOSProjectFormSheet(viewModel: ProjectFormViewModel(project: nil, defaultColorHex: "#4F8EF7", repository: env.projects))
}
#endif
