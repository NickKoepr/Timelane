import SwiftUI

struct ProjectsScreen: View {
    @State private var viewModel: ProjectsViewModel
    @State private var exportModel: MonthExportViewModel
    @State private var form: ProjectFormTarget?
    @State private var pendingExport: ExportFile?
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
                title: viewModel.monthTitle,
                shortTitle: viewModel.shortMonthTitle,
                isCurrentMonth: viewModel.isCurrentMonth,
                previous: viewModel.goToPreviousMonth,
                next: viewModel.goToNextMonth,
                current: viewModel.goToCurrentMonth
            )
            Divider()
            list
            ProjectsTotalFooter(showArchived: $viewModel.showArchived, total: viewModel.monthTotal)
        }
        .errorAlert($exportModel.errorMessage)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .toolbar {
            ToolbarItem {
                Button { exportModel.beginExport() } label: {
                    Label("Export…", systemImage: "square.and.arrow.up")
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .help("Export this month")
            }
            ToolbarItem {
                Button { form = .new } label: { Label("New project", systemImage: "plus") }
                    .keyboardShortcut("n", modifiers: .command)
            }
        }
        .task(id: viewModel.month) { await viewModel.task() }
        .sheet(item: $form) { target in
            ProjectFormSheet(viewModel: ProjectFormViewModel(
                project: target.project,
                defaultColorHex: ProjectColor.hex(forIndex: viewModel.allTotals.count),
                repository: environment.projects
            ))
        }
        .sheet(isPresented: $exportModel.isChoosingFormat, onDismiss: savePendingExport) {
            ExportFormatSheet(viewModel: exportModel, month: viewModel.month, monthTitle: viewModel.monthTitle) {
                pendingExport = $0
            }
        }
        .errorAlert($viewModel.errorMessage)
        .navigationTitle("Projects")
    }

    /// Runs after the format sheet is gone, so the save panel doesn't compete with it.
    private func savePendingExport() {
        guard let file = pendingExport else { return }
        pendingExport = nil
        guard let url = ExportSavePanel.chooseURL(fileName: file.fileName, contentType: file.contentType) else { return }
        exportModel.write(file, to: url)
    }

    @ViewBuilder private var list: some View {
        if !viewModel.isLoaded {
            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.rows.isEmpty {
            ProjectsEmptyState(hasAnyProjects: viewModel.hasAnyProjects, monthTitle: viewModel.monthTitle) {
                form = .new
            }
        } else {
            List(viewModel.rows) { row in
                ProjectRow(total: row)
                    .onTapGesture(count: 2) { form = .edit(row.project) }
                    .contextMenu { menu(for: row.project) }
            }
        }
    }

    @ViewBuilder private func menu(for project: Project) -> some View {
        Button("Edit…") { form = .edit(project) }
        if project.isArchived {
            Button("Unarchive") { Task { await viewModel.unarchive(project) } }
        } else {
            Button("Archive") { Task { await viewModel.archive(project) } }
        }
        Divider()
        Button("Delete", role: .destructive) { Task { await viewModel.delete(project) } }
    }
}

#Preview {
    ProjectsScreen(environment: .preview())
}

#Preview("Empty") {
    ProjectsScreen(environment: .inMemory()).frame(width: 800, height: 600)
}
