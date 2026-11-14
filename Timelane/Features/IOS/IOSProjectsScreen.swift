#if os(iOS)
import Foundation
import SwiftUI

/// The Projects tab: month totals per project, add / edit / archive / delete, and export of the month.
struct IOSProjectsScreen: View {
    @State private var viewModel: ProjectsViewModel
    @State private var exportModel: MonthExportViewModel
    @State private var form: ProjectFormTarget?
    @State private var projectToDelete: Project?
    @State private var pendingExport: ExportFile?
    @State private var exportDocument: ExportDocument?
    @State private var exportFile: ExportFile?
    @State private var isExporterPresented = false
    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
        _viewModel = State(initialValue: ProjectsViewModel(repository: environment.projects))
        _exportModel = State(initialValue: MonthExportViewModel(service: MonthExportService(
            projects: environment.projects, timeEntries: environment.timeEntries)))
    }

    var body: some View {
        VStack(spacing: 0) {
            MonthNavigationBar(
                title: viewModel.monthTitle, shortTitle: viewModel.shortMonthTitle,
                isCurrentMonth: viewModel.isCurrentMonth,
                previous: viewModel.goToPreviousMonth, next: viewModel.goToNextMonth, current: viewModel.goToCurrentMonth)
            Divider()
            list
            ProjectsTotalFooter(showArchived: $viewModel.showArchived, total: viewModel.monthTotal)
        }
        .navigationTitle("Projects")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { exportModel.beginExport() } label: { Label("Export", systemImage: "square.and.arrow.up") }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { form = .new } label: { Label("New project", systemImage: "plus") }
            }
        }
        .task(id: viewModel.month) { await viewModel.task() }
        .sheet(item: $form) { target in
            IOSProjectFormSheet(viewModel: ProjectFormViewModel(
                project: target.project, defaultColorHex: ProjectColor.hex(forIndex: viewModel.allTotals.count),
                repository: environment.projects))
        }
        .sheet(isPresented: $exportModel.isChoosingFormat, onDismiss: presentPendingExport) {
            IOSExportFormatSheet(viewModel: exportModel, month: viewModel.month, monthTitle: viewModel.monthTitle) {
                pendingExport = $0
            }
        }
        .fileExporter(isPresented: $isExporterPresented, document: exportDocument,
                      contentType: exportFile?.contentType ?? .data,
                      defaultFilename: exportFile.map(Self.baseName)) { result in
            if case .failure(let error) = result { exportModel.errorMessage = error.localizedDescription }
        }
        .confirmationDialog("Delete project?", isPresented: Binding(get: { projectToDelete != nil },
                                                                    set: { if !$0 { projectToDelete = nil } }),
                            presenting: projectToDelete) { project in
            Button("Delete “\(project.name)”", role: .destructive) { Task { await viewModel.delete(project) } }
        } message: { _ in
            Text("Its logged hours are deleted too.")
        }
        .errorAlert($exportModel.errorMessage)
        .errorAlert($viewModel.errorMessage)
    }

    /// Runs after the format sheet is gone, so the file exporter doesn't compete with it.
    private func presentPendingExport() {
        guard let file = pendingExport else { return }
        pendingExport = nil
        exportFile = file
        exportDocument = ExportDocument(data: file.data)
        isExporterPresented = true
    }

    /// The suggested name without extension; the exporter adds it from the content type.
    private static func baseName(_ file: ExportFile) -> String {
        URL(fileURLWithPath: file.fileName).deletingPathExtension().lastPathComponent
    }

    @ViewBuilder private var list: some View {
        if !viewModel.isLoaded {
            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.rows.isEmpty {
            ProjectsEmptyState(hasAnyProjects: viewModel.hasAnyProjects, monthTitle: viewModel.monthTitle) { form = .new }
        } else {
            List(viewModel.rows) { row in
                Button { form = .edit(row.project) } label: { ProjectRow(total: row) }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button("Delete", role: .destructive) { projectToDelete = row.project }
                        archiveButton(for: row.project)
                    }
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder private func archiveButton(for project: Project) -> some View {
        if project.isArchived {
            Button("Unarchive") { Task { await viewModel.unarchive(project) } }.tint(.blue)
        } else {
            Button("Archive") { Task { await viewModel.archive(project) } }.tint(.orange)
        }
    }
}

#Preview {
    NavigationStack { IOSProjectsScreen(environment: .preview()) }
}
#endif
