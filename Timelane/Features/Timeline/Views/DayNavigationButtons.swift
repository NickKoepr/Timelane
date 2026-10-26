import SwiftUI

/// "‹ Today ›" — never truncates. Shortcuts live in `DayNavigationShortcuts`.
struct DayNavigationButtons: View {
    let viewModel: TimelineViewModel

    var body: some View {
        HStack(spacing: 8) {
            Button { viewModel.goToPreviousDay() } label: { Image(systemName: "chevron.left") }
                .help("Previous day (⌘←)")
            Button("Today") { viewModel.goToToday() }
                .disabled(viewModel.isToday)
                .help("Go to today (⌘T)")
            Button { viewModel.goToNextDay() } label: { Image(systemName: "chevron.right") }
                .help("Next day (⌘→)")
        }
        .lineLimit(1)
        .fixedSize()
    }
}
