import SwiftUI

/// ⌘Z / ⇧⌘Z for logged hours. Registered once in hidden buttons (see `DayNavigationShortcuts`).
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
