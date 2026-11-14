#if os(iOS)
import SwiftUI

/// Asks which format to export the month in; reports the prepared file through `onExport`.
struct IOSExportFormatSheet: View {
    @Bindable var viewModel: MonthExportViewModel
    let month: DateRange
    let monthTitle: String
    let onExport: (ExportFile) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Picker("Format", selection: $viewModel.selectedFormatID) {
                    ForEach(viewModel.formats, id: \.id) { format in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(format.displayName)
                            Text(format.summary).font(.caption).foregroundStyle(.secondary)
                        }
                        .tag(format.id)
                    }
                }
                .exportFormatPickerStyle()
                .labelsHidden()
            }
            .navigationTitle("Export \(monthTitle)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Export") { export() }.disabled(viewModel.isExporting)
                }
            }
        }
        .presentationDetents([.medium])
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
    IOSExportFormatSheet(
        viewModel: MonthExportViewModel(
            service: MonthExportService(projects: environment.projects, timeEntries: environment.timeEntries)),
        month: .month(of: .now), monthTitle: "October 2026", onExport: { _ in })
}
#endif
