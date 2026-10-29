import CoreGraphics
import Foundation

/// The heatmap square under the pointer and its frame in the "heatmap" coordinate space.
@MainActor @Observable
final class HeatmapHoverState {
    private(set) var day: Date?
    /// nil until the hovered square has reported its frame.
    private(set) var frame: CGRect?

    func enter(day: Date) {
        guard self.day != day else { return }
        self.day = day
        frame = nil
    }

    func update(frame: CGRect) { self.frame = frame }

    /// Only clears when the pointer left the square that is currently shown, so moving straight from one
    /// square into the next never hides the new card.
    func leave(day: Date) {
        if self.day == day { clear() }
    }

    func clear() {
        day = nil
        frame = nil
    }
}
