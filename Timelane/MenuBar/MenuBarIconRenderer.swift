import AppKit

/// Builds the menu bar images. `.normal` is the template clock; `.recording` is a non-template
/// clock (tinted with the menu bar foreground colour) with a small red dot at the bottom right.
@MainActor
enum MenuBarIconRenderer {
    static let size = NSSize(width: 18, height: 18)
    /// Dot and the transparent ring around it, in unflipped canvas coordinates.
    static let dotRect = NSRect(x: 12, y: 0, width: 6, height: 6)
    static let ringRect = dotRect.insetBy(dx: -1.5, dy: -1.5)

    private static let normalImage: NSImage = NSImage(named: "MenuBarIcon") ?? NSImage(size: size)
    private static let recordingImage: NSImage = makeRecordingImage()

    static func image(for style: MenuBarIconStyle) -> NSImage {
        style == .recording ? recordingImage : normalImage
    }

    private static func makeRecordingImage() -> NSImage {
        let template = normalImage
        let image = NSImage(size: size, flipped: false) { rect in
            // Clock tinted with the foreground colour (re-evaluated per appearance).
            template.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            NSColor.labelColor.set()
            rect.fill(using: .sourceAtop)
            // Transparent ring so the dot does not merge with the clock outline.
            NSGraphicsContext.current?.saveGraphicsState()
            NSGraphicsContext.current?.compositingOperation = .clear
            NSBezierPath(ovalIn: ringRect).fill()
            NSGraphicsContext.current?.restoreGraphicsState()
            NSColor.systemRed.setFill()
            NSBezierPath(ovalIn: dotRect).fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}
