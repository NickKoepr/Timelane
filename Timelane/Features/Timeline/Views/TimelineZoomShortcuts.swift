import SwiftUI

/// Hidden buttons carrying the zoom shortcuts ⌘= (same key as ⌘+ on most layouts) and ⌘0 (back to the overview).
struct TimelineZoomShortcuts: View {
    let apply: (ZoomChange) -> Void

    var body: some View {
        Group {
            Button("Zoom in") { apply { $0.zoomIn() } }.keyboardShortcut("=", modifiers: .command)
            Button("Reset zoom") { apply { $0.set(.hour) } }.keyboardShortcut("0", modifiers: .command)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    /// ⌘ + `key`, only when `isEnabled` (so a bar's variants don't each register the same shortcut).
    @ViewBuilder func keyboardShortcutIf(_ isEnabled: Bool, _ key: KeyEquivalent) -> some View {
        if isEnabled { keyboardShortcut(key, modifiers: .command) } else { self }
    }
}
