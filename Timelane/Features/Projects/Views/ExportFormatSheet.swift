import SwiftUI

/// Asks which format to export the month in. Reports the prepared file through `onExport`.
struct ExportFormatSheet: View {
    @Bindable var viewModel: MonthExportViewModel
    let month: DateRange
    let monthTitle: String
    let onExport: (ExportFile) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export \(monthTitle)").font(.headline)
            Picker("Format", selection: $viewModel.selectedFormatID) {
                ForEach(viewModel.formats, id: \.id) { format in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(format.displayName)
                        Text(format.summary).font(.caption).foregroundStyle(.secondary)
                    }
                    .tag(format.id)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Export…") { export() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(viewModel.isExporting)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private func export() {
        Task {
            if let file = await viewModel.prepareFile(for: month) { onExport(file) }
            dismiss()
        }
    }
}

#Preview {
    let environment = AppEnvironment.preview()
    ExportFormatSheet(
        viewModel: MonthExportViewModel(
            service: MonthExportService(projects: environment.projects, timeEntries: environment.timeEntries)),
        month: .month(of: .now), monthTitle: "October 2026", onExport: { _ in })
}
