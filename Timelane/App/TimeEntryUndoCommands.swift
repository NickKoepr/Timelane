import SwiftUI

/// Edit ▸ Undo / Redo (⌘Z / ⇧⌘Z) for logged hours; replaces the system items, which only know `NSUndoManager`.
///
/// Text editing keeps working: while a text field is being edited and has its own undo/redo step, the action is
/// forwarded to it (see `TextUndoForwarding`). Known limitation: the enabled state follows `TimeEntryHistory`
/// only, so with an empty history the items are greyed out while typing in a field.
struct TimeEntryUndoCommands: Commands {
    let history: TimeEntryHistory

    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button("Undo") {
                if !TextUndoForwarding.forwardUndo() { Task { await history.undo() } }
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(!history.canUndo)

            Button("Redo") {
                if !TextUndoForwarding.forwardRedo() { Task { await history.redo() } }
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(!history.canRedo)
        }
    }
}
