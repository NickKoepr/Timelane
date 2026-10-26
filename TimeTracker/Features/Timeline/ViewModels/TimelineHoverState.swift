import CoreGraphics
import Foundation

/// The block under the pointer and its frame in the "timeline" coordinate space.
@MainActor @Observable
final class TimelineHoverState {
    private(set) var hovered: HoverTarget?
    private(set) var frame: CGRect = .zero

    func enter(_ target: HoverTarget, frame: CGRect) {
        hovered = target
        self.frame = frame
    }

    /// The hovered block changed (resized, moved, grew): refresh what the card shows.
    func update(_ target: HoverTarget, frame: CGRect) {
        guard hovered?.id == target.id else { return }
        enter(target, frame: frame)
    }

    /// Only clears when the pointer left the block that is currently shown, so moving straight from one
    /// block into the next never hides the new card.
    func leave(_ target: HoverTarget) {
        if hovered?.id == target.id { hovered = nil }
    }
}
