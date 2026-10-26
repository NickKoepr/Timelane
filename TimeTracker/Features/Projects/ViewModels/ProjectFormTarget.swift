import Foundation

/// What the project sheet is opened for.
enum ProjectFormTarget: Identifiable {
    case new
    case edit(Project)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let project): "edit-\(project.id ?? 0)"
        }
    }

    var project: Project? {
        if case .edit(let project) = self { return project }
        return nil
    }
}
