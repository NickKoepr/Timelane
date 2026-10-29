import CoreGraphics

/// Turns a continuous pinch magnification into discrete zoom steps: one level per `threshold` change,
/// so a single gesture never jumps several levels at once.
struct PinchZoomStepper {
    var threshold: CGFloat = 1.25
    private var base: CGFloat = 1
    private var total: CGFloat = 1

    /// +1 zoom in, -1 zoom out, 0 nothing yet. `magnification` is the gesture's total scale (1 = unchanged).
    mutating func step(for magnification: CGFloat) -> Int {
        guard magnification > 0 else { return 0 }
        let ratio = magnification / base
        if ratio >= threshold { base = magnification; return 1 }
        if ratio <= 1 / threshold { base = magnification; return -1 }
        return 0
    }

    /// Same, for `NSEvent.magnification`, which is a small delta per event (0.02 = 2%) instead of a total scale.
    mutating func step(forDelta delta: CGFloat) -> Int {
        total *= 1 + delta
        return step(for: total)
    }

    mutating func reset() { base = 1; total = 1 }
}
