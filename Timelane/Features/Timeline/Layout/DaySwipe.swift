import CoreGraphics

/// Turns a horizontal swipe over the timeline into a day change; mostly vertical drags are scrolling.
enum DaySwipe {
    static let minimumDistance: CGFloat = 70

    /// -1 = previous day (swipe right), +1 = next day (swipe left), 0 = not a day swipe.
    static func dayOffset(forTranslation translation: CGSize) -> Int {
        guard abs(translation.width) >= minimumDistance, abs(translation.width) > abs(translation.height) * 2 else { return 0 }
        return translation.width < 0 ? 1 : -1
    }
}
