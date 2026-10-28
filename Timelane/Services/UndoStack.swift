import Foundation

/// Pure undo/redo bookkeeping: a new change clears the redo stack; the undo stack is capped.
struct UndoStack<Element: Sendable>: Sendable {
    let limit: Int
    private(set) var undoStack: [Element] = []
    private(set) var redoStack: [Element] = []

    init(limit: Int = 50) { self.limit = limit }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    mutating func record(_ element: Element) {
        undoStack.append(element)
        if undoStack.count > limit { undoStack.removeFirst(undoStack.count - limit) }
        redoStack.removeAll()
    }

    /// The element that undo would take, without removing it.
    var nextUndo: Element? { undoStack.last }
    var nextRedo: Element? { redoStack.last }

    /// Moves the top of the undo stack to the redo stack (call after the undo succeeded).
    mutating func didUndo() {
        guard let element = undoStack.popLast() else { return }
        redoStack.append(element)
    }

    mutating func didRedo() {
        guard let element = redoStack.popLast() else { return }
        undoStack.append(element)
    }
}
