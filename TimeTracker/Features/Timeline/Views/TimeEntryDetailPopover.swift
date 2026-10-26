import SwiftUI

struct TimeEntryDetailPopover: View {
    @State var viewModel: TimeEntryDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Project", selection: $viewModel.projectId) {
                ForEach(viewModel.projects) { project in
                    Text(project.name).tag(project.id ?? 0)
                }
            }
            HStack {
                DatePicker("From", selection: $viewModel.start, displayedComponents: .hourAndMinute)
                DatePicker("To", selection: $viewModel.end, displayedComponents: .hourAndMinute)
            }
            .datePickerStyle(.field)
            TextField("Note", text: $viewModel.note, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
            if let message = viewModel.errorMessage {
                Text(message).font(.caption).foregroundStyle(.red)
            }
            HStack {
                Button("Delete", role: .destructive) { Task { await viewModel.delete() } }
                Spacer()
                Button("Save") { Task { await viewModel.save() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!viewModel.canSave)
            }
        }
        .padding(14)
        .frame(width: 300)
    }
}
