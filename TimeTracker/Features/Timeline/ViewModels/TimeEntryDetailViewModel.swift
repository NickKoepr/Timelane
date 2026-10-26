import Foundation

@MainActor @Observable
final class TimeEntryDetailViewModel {
    var projectId: Int64
    var note: String
    var start: Date
    var end: Date
    private(set) var errorMessage: String?

    let entry: TimeEntry
    let projects: [Project]
    private let editor: TimeEntryEditor
    private let onFinish: () -> Void

    /// Archived projects are not offered, except the one the entry already uses.
    init(entry: TimeEntry, projects: [Project], editor: TimeEntryEditor, onFinish: @escaping () -> Void) {
        self.entry = entry
        self.projects = projects.filter { !$0.isArchived || $0.id == entry.projectId }
        self.projectId = entry.projectId
        self.note = entry.note ?? ""
        self.start = entry.start
        self.end = entry.end
        self.editor = editor
        self.onFinish = onFinish
    }

    var canSave: Bool { end.timeIntervalSince(start) >= TimeEntryEditor.minimumDuration }

    func save() async {
        var changed = entry
        changed.projectId = projectId
        changed.start = start
        changed.end = end
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        changed.note = trimmed.isEmpty ? nil : trimmed
        do {
            try await editor.update(changed)
            onFinish()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete() async {
        do {
            try await editor.delete(entry)
            onFinish()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
