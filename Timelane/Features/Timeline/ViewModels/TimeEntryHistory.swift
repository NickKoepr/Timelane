import Foundation

/// Undo/redo of time-entry changes, shared by the main window and the menu bar panel.
@MainActor @Observable
final class TimeEntryHistory {
    private let repository: any TimeEntryRepository
    private var stack = UndoStack<TimeEntryChange>()
    var errorMessage: String?

    var canUndo: Bool { stack.canUndo }
    var canRedo: Bool { stack.canRedo }

    /// Undo/redo write straight to the repository, so they never record themselves.
    init(repository: any TimeEntryRepository) { self.repository = repository }

    func record(_ change: TimeEntryChange) { stack.record(change) }

    /// A remote change (iCloud sync) touched these entries (E1). Remote changes never go on the stack; the
    /// steps that refer to a changed row would write stale data, so the whole history is dropped.
    func invalidate(touching ids: Set<Int64>) {
        let steps = stack.undoStack + stack.redoStack
        let touched = steps.contains { step in
            (step.before + step.after).contains { entry in entry.id.map(ids.contains) ?? false }
        }
        if touched { stack.removeAll() }
    }

    func undo() async {
        guard let change = stack.nextUndo else { return }
        if await apply(change.inverted) { stack.didUndo() }
    }

    func redo() async {
        guard let change = stack.nextRedo else { return }
        if await apply(change) { stack.didRedo() }
    }

    private func apply(_ change: TimeEntryChange) async -> Bool {
        do {
            try await repository.save(change.after, deleting: change.removedIds)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
