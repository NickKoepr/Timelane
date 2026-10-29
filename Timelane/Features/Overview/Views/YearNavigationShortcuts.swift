import SwiftUI

/// ⌘← / ⌘→ / ⌘T for the year bar, registered once whichever variant is showing.
struct YearNavigationShortcuts: View {
    let isCurrentYear: Bool
    let previous: () -> Void
    let next: () -> Void
    let current: () -> Void

    var body: some View {
        HStack {
            Button("Previous year", action: previous).keyboardShortcut(.leftArrow, modifiers: .command)
            Button("Next year", action: next).keyboardShortcut(.rightArrow, modifiers: .command)
            Button("This year", action: current).keyboardShortcut("t", modifiers: .command)
                .disabled(isCurrentYear)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
