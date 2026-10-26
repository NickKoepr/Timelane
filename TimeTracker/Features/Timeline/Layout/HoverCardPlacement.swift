import CoreGraphics

/// Pure placement of the hover card next to a block, kept inside the column and the visible area.
enum HoverCardPlacement {
    static let gap: CGFloat = 8
    static let margin: CGFloat = 4

    /// Top-left corner of the card. `visibleTop`/`visibleBottom` are in the same coordinate space as `block`.
    static func origin(for block: CGRect, opensToLeft: Bool, cardSize: CGSize, columnWidth: CGFloat,
                       columnHeight: CGFloat, minX: CGFloat, visibleTop: CGFloat, visibleBottom: CGFloat) -> CGPoint {
        var x = opensToLeft ? block.minX - gap - cardSize.width : block.maxX + gap
        x = min(x, columnWidth - cardSize.width - margin)
        x = max(x, minX)

        var y = block.minY
        y = min(y, visibleBottom - cardSize.height - margin)
        y = max(y, visibleTop + margin)
        y = min(y, columnHeight - cardSize.height)
        y = max(y, 0)
        return CGPoint(x: x, y: y)
    }
}
