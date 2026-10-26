import SwiftUI

/// The drag that selects a time range. Shared by the background layer and the app-session blocks,
/// so selecting works over both lanes, filled or empty, in the past and the future.
struct SelectionDragGesture: Gesture {
    let viewModel: TimelineViewModel

    var body: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("timeline"))
            .onChanged { viewModel.updateSelection(startY: $0.startLocation.y, currentY: $0.location.y) }
            .onEnded { _ in viewModel.finishSelection() }
    }
}
