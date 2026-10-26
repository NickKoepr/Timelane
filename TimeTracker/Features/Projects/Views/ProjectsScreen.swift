import SwiftUI

struct ProjectsScreen: View {
    @State private var viewModel: ProjectsViewModel
    @State private var form: ProjectFormTarget?
    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
        _viewModel = State(initialValue: ProjectsViewModel(repository: environment.projects))
    }

    var body: some View {
        VStack(spacing: 0) {
            MonthNavigationBar(
                title: viewModel.monthTitle,
                isCurrentMonth: viewModel.isCurrentMonth,
                previous: viewModel.goToPreviousMonth,
                next: viewModel.goToNextMonth,
                current: viewModel.goToCurrentMonth
            )
            Divider()
            list
            ProjectsTotalFooter(showArchived: $viewModel.showArchived, total: viewModel.monthTotal)
        }
        .toolbar {
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
        .errorAlert($viewModel.errorMessage)
        .navigationTitle("Projects")
    }

    @ViewBuilder private var list: some View {
        if viewModel.rows.isEmpty {
            ContentUnavailableView("No projects yet", systemImage: "folder.badge.plus",
                                   description: Text("Add a project with the + button."))
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
