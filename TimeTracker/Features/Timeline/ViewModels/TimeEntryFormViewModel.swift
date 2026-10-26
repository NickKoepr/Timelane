import Foundation

/// Drives the "New / Edit time entry" window: form values, project search, save and delete.
@MainActor @Observable
final class TimeEntryFormViewModel: Identifiable {
    let id = UUID()
    var form: TimeEntryForm
    var search: ProjectSearch
    private(set) var errorMessage: String?
    private(set) var isBusy = false

    private let projectRepository: any ProjectRepository
    private let editor: TimeEntryEditor
    /// Called when the window should close; the argument is the project that was saved (nil on cancel/delete).
    private let onFinish: (Int64?) -> Void

    /// Archived projects are not offered, except the one the entry already uses.
    init(form: TimeEntryForm, projects: [Project], projectRepository: any ProjectRepository,
         editor: TimeEntryEditor, allowsCreatingProjects: Bool = true,
         onFinish: @escaping (Int64?) -> Void) {
        let usedId = form.projectId
        let offered = projects.filter { !$0.isArchived || $0.id == usedId }
        self.form = form
        self.search = ProjectSearch(projects: offered, highlightedId: form.projectId ?? offered.first?.id,
                                    allowsCreating: allowsCreatingProjects)
        self.projectRepository = projectRepository
        self.editor = editor
        self.onFinish = onFinish
    }

    var heading: String { form.isEditing ? "Edit time entry" : "New time entry" }
    var canSave: Bool { form.canSave && !isBusy }

    func choose(_ project: Project) {
        form.projectId = project.id
        search.highlight(project.id)
    }

    /// Enter in the search field: choose the highlighted project, or create the typed one.
    func confirmSearch() async {
        if let project = search.highlightedProject {
            choose(project)
        } else if search.newProjectName != nil {
            await createProject()
        }
    }

    func createProject() async {
        guard let name = search.newProjectName else { return }
        do {
            let color = ProjectColor.hex(forIndex: search.projects.count)
            let saved = try await projectRepository.save(Project(name: name, colorHex: color))
            search.add(saved)
            form.projectId = saved.id
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save() async {
        guard canSave, let entry = form.makeEntry() else { return }
        await perform {
            if form.isEditing {
                try await editor.update(entry)
            } else {
                try await editor.create(projectId: entry.projectId, range: entry.range, title: entry.title, note: entry.note)
            }
            onFinish(entry.projectId)
        }
    }

    func delete() async {
        guard case .edit(let entry) = form.mode else { return }
        await perform {
            try await editor.delete(entry)
            onFinish(nil)
        }
    }

    func cancel() { onFinish(nil) }

    private func perform(_ work: () async throws -> Void) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do { try await work() } catch { errorMessage = error.localizedDescription }
    }
}
