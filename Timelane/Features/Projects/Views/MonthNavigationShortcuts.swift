import SwiftUI

/// ⌘← / ⌘→ / ⌘T for the month bar, registered once whichever variant is showing.
struct MonthNavigationShortcuts: View {
    let isCurrentMonth: Bool
    let previous: () -> Void
    let next: () -> Void
    let current: () -> Void

    var body: some View {
        HStack {
            Button("Previous month", action: previous).keyboardShortcut(.leftArrow, modifiers: .command)
            Button("Next month", action: next).keyboardShortcut(.rightArrow, modifiers: .command)
            Button("This month", action: current).keyboardShortcut("t", modifiers: .command)
                .disabled(isCurrentMonth)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
