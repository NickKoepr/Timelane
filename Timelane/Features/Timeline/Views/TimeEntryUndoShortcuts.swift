import SwiftUI

/// ⌘Z / ⇧⌘Z for logged hours in the menu bar panel. Registered once in hidden buttons (see `DayNavigationShortcuts`).
/// The main window uses Edit ▸ Undo / Redo instead (`TimeEntryUndoCommands`).
struct TimeEntryUndoShortcuts: View {
    let history: TimeEntryHistory

    var body: some View {
        HStack {
            Button("Undo") { Task { await history.undo() } }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!history.canUndo)
            Button("Redo") { Task { await history.redo() } }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!history.canRedo)
        }
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview {
    TimeEntryUndoShortcuts(history: AppEnvironment.preview().timeEntryHistory)
}
