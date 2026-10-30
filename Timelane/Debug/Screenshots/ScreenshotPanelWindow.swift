#if DEBUG
import AppKit
import SwiftUI

/// The menu bar panel's content in a borderless, rounded window: a real `MenuBarExtra` panel can't be opened from code.
final class ScreenshotPanelWindow: NSWindow {
    init(content: some View) {
        let size = MenuBarContentView.size
        super.init(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        let host = NSHostingView(rootView: content)
        host.wantsLayer = true
        host.layer?.cornerRadius = 14
        host.layer?.cornerCurve = .continuous
        host.layer?.masksToBounds = true
        contentView = host
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
    }

    override var canBecomeKey: Bool { true }
}
#endif
