import Foundation

/// Pure state of the project search list: filtering, keyboard highlight and inline-create name.
struct ProjectSearch: Equatable {
    private(set) var projects: [Project]
    var query = "" { didSet { if query != oldValue { highlightedId = filtered.first?.id } } }
    private(set) var highlightedId: Int64?
    /// False in the menu bar: projects are managed in the main window only.
    let allowsCreating: Bool

    init(projects: [Project], highlightedId: Int64?, allowsCreating: Bool = true) {
        self.allowsCreating = allowsCreating
        self.projects = projects
        self.highlightedId = highlightedId
    }

    var filtered: [Project] {
        let text = trimmedQuery
        guard !text.isEmpty else { return projects }
        return projects.filter { $0.name.localizedCaseInsensitiveContains(text) }
    }

    /// Offer inline creation when the typed name matches no existing project.
    var newProjectName: String? {
        let text = trimmedQuery
        guard allowsCreating, !text.isEmpty,
              !projects.contains(where: { $0.name.caseInsensitiveCompare(text) == .orderedSame }) else { return nil }
        return text
    }

    /// The project Enter would choose, if any.
    var highlightedProject: Project? { filtered.first { $0.id == highlightedId } }

    mutating func moveHighlight(by offset: Int) {
        let list = filtered
        guard !list.isEmpty else { return }
        let current = list.firstIndex { $0.id == highlightedId } ?? (offset > 0 ? -1 : list.count)
        highlightedId = list[min(max(current + offset, 0), list.count - 1)].id
    }

    mutating func add(_ project: Project) {
        projects.append(project)
        query = ""
        highlightedId = project.id
    }

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespaces) }
}
