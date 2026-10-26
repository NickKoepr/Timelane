import SwiftUI

/// ⌘← / ⌘→ / ⌘T and the zoom shortcuts, registered once for the whole bar whichever variant is showing.
struct DayNavigationShortcuts: View {
    let viewModel: TimelineViewModel
    let changeZoom: (ZoomChange) -> Void

    var body: some View {
        HStack {
            Button("Previous day") { viewModel.goToPreviousDay() }.keyboardShortcut(.leftArrow, modifiers: .command)
            Button("Next day") { viewModel.goToNextDay() }.keyboardShortcut(.rightArrow, modifiers: .command)
            Button("Today") { viewModel.goToToday() }.keyboardShortcut("t", modifiers: .command)
                .disabled(viewModel.isToday)
            Button("Zoom out") { changeZoom { $0.zoomOut() } }.keyboardShortcut("-", modifiers: .command)
                .disabled(!viewModel.zoomState.canZoomOut)
            Button("Zoom in") { changeZoom { $0.zoomIn() } }.keyboardShortcut("+", modifiers: .command)
                .disabled(!viewModel.zoomState.canZoomIn)
            TimelineZoomShortcuts(apply: changeZoom)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
