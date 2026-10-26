import SwiftUI

struct MonthNavigationBar: View {
    let title: String
    let isCurrentMonth: Bool
    let previous: () -> Void
    let next: () -> Void
    let current: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: previous) { Image(systemName: "chevron.left") }
                .keyboardShortcut(.leftArrow, modifiers: .command)
                .help("Previous month")
            Text(title)
                .font(.title2.weight(.semibold))
                .frame(minWidth: 170)
            Button(action: next) { Image(systemName: "chevron.right") }
                .keyboardShortcut(.rightArrow, modifiers: .command)
                .help("Next month")
            Button("This month", action: current)
                .keyboardShortcut("t", modifiers: .command)
                .disabled(isCurrentMonth)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

#Preview {
    MonthNavigationBar(title: "October 2026", isCurrentMonth: true, previous: {}, next: {}, current: {})
}
