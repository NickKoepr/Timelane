import AppKit

/// Lets Edit ▸ Undo / Redo keep working for text editing. When a text field is being edited and has something
/// to undo (or redo), the action goes to the responder chain (`undo:` / `redo:`) instead of the time-entry history.
@MainActor
enum TextUndoForwarding {
    /// Sends `undo:` to the field editor when it has something to undo. Returns whether it did.
    static func forwardUndo() -> Bool {
        forward(Selector(("undo:")), when: { $0.canUndo })
    }

    /// Sends `redo:` to the field editor when it has something to redo. Returns whether it did.
    static func forwardRedo() -> Bool {
        forward(Selector(("redo:")), when: { $0.canRedo })
    }

    private static func forward(_ action: Selector, when canPerform: (UndoManager) -> Bool) -> Bool {
        guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView,
              let undoManager = textView.undoManager,
              canPerform(undoManager) else { return false }
        return NSApp.sendAction(action, to: nil, from: nil)
    }
}
