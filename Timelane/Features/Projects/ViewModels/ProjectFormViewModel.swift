import Foundation

@MainActor @Observable
final class ProjectFormViewModel {
    var name: String
    var colorHex: String
    var customId: String
    var errorMessage: String?

    let isEditing: Bool
    private let original: Project?
    private let repository: any ProjectRepository

    /// `project == nil` creates a new project using `defaultColorHex`.
    init(project: Project?, defaultColorHex: String, repository: any ProjectRepository) {
        self.original = project
        self.isEditing = project != nil
        self.name = project?.name ?? ""
        self.colorHex = project?.colorHex ?? defaultColorHex
        self.customId = project?.customId ?? ""
        self.repository = repository
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var customIdTooLong: Bool { (ProjectCustomId.normalized(customId)?.count ?? 0) > ProjectCustomId.maxLength }
    var canSave: Bool { !trimmedName.isEmpty && !customIdTooLong }

    /// Returns true when saved; otherwise `errorMessage` is set.
    func save() async -> Bool {
        guard canSave else { return false }
        var project = original ?? Project(name: trimmedName, colorHex: colorHex)
        project.name = trimmedName
        project.colorHex = colorHex
        project.customId = ProjectCustomId.normalized(customId)
        do {
            _ = try await repository.save(project)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
