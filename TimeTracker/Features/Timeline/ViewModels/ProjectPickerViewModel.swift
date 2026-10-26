import Foundation

@MainActor @Observable
final class ProjectPickerViewModel {
    var searchText = "" { didSet { if searchText != oldValue { highlightFirstMatch() } } }
    var note = ""
    private(set) var highlightedId: Int64?
    private(set) var errorMessage: String?

    let range: DateRange
    private let projects: [Project]
    private let projectRepository: any ProjectRepository
    private let editor: TimeEntryEditor
    private let onFinish: (Int64?) -> Void

    init(range: DateRange, projects: [Project], lastProjectId: Int64?,
         projectRepository: any ProjectRepository, editor: TimeEntryEditor,
         onFinish: @escaping (Int64?) -> Void) {
        self.range = range
        self.projects = projects.filter { !$0.isArchived }
        self.projectRepository = projectRepository
        self.editor = editor
        self.onFinish = onFinish
        let preselected = self.projects.first { $0.id == lastProjectId } ?? self.projects.first
        self.highlightedId = preselected?.id
    }

    var filtered: [Project] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return projects }
        return projects.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    /// Offer inline creation when the typed name matches no existing project.
    var newProjectName: String? {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty,
              !projects.contains(where: { $0.name.caseInsensitiveCompare(query) == .orderedSame }) else { return nil }
        return query
    }

    func moveHighlight(by offset: Int) {
        let list = filtered
        guard !list.isEmpty else { return }
        let current = list.firstIndex { $0.id == highlightedId } ?? (offset > 0 ? -1 : list.count)
        highlightedId = list[min(max(current + offset, 0), list.count - 1)].id
    }

    /// Enter: registers on the highlighted project, or creates the typed project when nothing matches.
    func confirm() async {
        if let project = filtered.first(where: { $0.id == highlightedId }) {
            await select(project)
        } else if newProjectName != nil {
            await createAndSelect()
        }
    }

    func select(_ project: Project) async {
        guard let id = project.id else { return }
        await register(projectId: id)
    }

    func createAndSelect() async {
        guard let name = newProjectName else { return }
        do {
            let color = ProjectColor.hex(forIndex: projects.count)
            let saved = try await projectRepository.save(Project(name: name, colorHex: color))
            if let id = saved.id { await register(projectId: id) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func register(projectId: Int64) async {
        do {
            try await editor.create(projectId: projectId, range: range, note: note)
            onFinish(projectId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func highlightFirstMatch() { highlightedId = filtered.first?.id }
}
