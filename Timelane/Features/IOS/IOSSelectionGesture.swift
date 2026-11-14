#if os(iOS)
import SwiftUI
import UIKit

/// Touch and hold on an empty spot, then drag: selects a time range (a quick swipe still scrolls).
/// A UIKit long-press recognizer instead of SwiftUI's `LongPressGesture.sequenced(before: DragGesture)`: the SwiftUI
/// sequence claims every touch on the lane, so the scroll view never got to scroll. UIKit's long press only begins after
/// the finger rests, and fails on movement before that, leaving the pan to the scroll view.
/// Uses the same selection intents as the Mac drag, so the overlay and the entry form behave the same.
struct IOSSelectionGesture: UIGestureRecognizerRepresentable {
    let viewModel: TimelineViewModel

    final class Coordinator { var startY: CGFloat = 0 }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = 0.35
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        let y = context.converter.location(in: .named("timeline")).y
        switch recognizer.state {
        case .began:
            context.coordinator.startY = y
            viewModel.updateSelection(startY: y, currentY: y)
        case .changed:
            viewModel.updateSelection(startY: context.coordinator.startY, currentY: y)
        case .ended:
            viewModel.finishSelection()
        case .cancelled, .failed:
            viewModel.cancelRegistration()
        default:
            break
        }
    }
}
#endif
