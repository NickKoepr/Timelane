import AppKit
import OSLog
import SwiftUI

/// Forwards trackpad magnify events that happen over this view to `onMagnify` (delta per event, phase).
/// SwiftUI's `MagnifyGesture` does not fire in the menu bar panel, so this listens at the AppKit level.
/// Events are never consumed, so scrolling and drags keep working.
struct MagnifyEventMonitor: NSViewRepresentable {
    let onMagnify: (CGFloat, NSEvent.Phase) -> Void

    func makeNSView(context: Context) -> MonitorView {
        let view = MonitorView()
        view.onMagnify = onMagnify
        return view
    }

    func updateNSView(_ view: MonitorView, context: Context) { view.onMagnify = onMagnify }

    static func dismantleNSView(_ view: MonitorView, coordinator: ()) { view.removeMonitor() }

    final class MonitorView: NSView {
        private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Timelane", category: "zoom")
        var onMagnify: (CGFloat, NSEvent.Phase) -> Void = { _, _ in }
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            removeMonitor()
            guard let window else { return }
            Self.logger.debug("Magnify monitor installed in \(String(describing: type(of: window)), privacy: .public)")
            monitor = NSEvent.addLocalMonitorForEvents(matching: .magnify) { [weak self] event in
                MainActor.assumeIsolated { self?.handle(event) }
                return event
            }
        }

        private func handle(_ event: NSEvent) {
            guard let window, event.window === window,
                  bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
            if event.phase.contains(.began) { Self.logger.debug("Magnify began in the timeline") }
            onMagnify(event.magnification, event.phase)
        }

        func removeMonitor() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }
    }
}
