#if os(iOS)
import SwiftUI

/// Touch and hold on an empty spot, then drag: selects a time range (the finger would otherwise scroll).
/// Uses the same selection intents as the Mac drag, so the overlay and the entry form behave the same.
struct IOSSelectionGesture: Gesture {
    let viewModel: TimelineViewModel

    var body: some Gesture {
        LongPressGesture(minimumDuration: 0.35)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("timeline")))
            .onChanged { value in
                guard case .second(true, let drag?) = value else { return }
                viewModel.updateSelection(startY: drag.startLocation.y, currentY: drag.location.y)
            }
            .onEnded { value in
                guard case .second(true, _) = value else { return }
                viewModel.finishSelection()
            }
    }
}
#endif
