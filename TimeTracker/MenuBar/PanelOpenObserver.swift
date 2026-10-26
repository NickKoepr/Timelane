import AppKit
import SwiftUI

/// Calls `onOpen` every time the window hosting this view becomes key or visible again.
/// `onAppear`/`task` of MenuBarExtra content only run once, not on each open of the panel.
struct PanelOpenObserver: NSViewRepresentable {
    let onOpen: () -> Void

    func makeNSView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.onOpen = onOpen
        return view
    }

    func updateNSView(_ view: ObserverView, context: Context) { view.onOpen = onOpen }

    final class ObserverView: NSView {
        var onOpen: () -> Void = {}
        private var tokens: [NSObjectProtocol] = []

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            tokens.forEach(NotificationCenter.default.removeObserver)
            tokens = []
            guard let window else { return }
            let center = NotificationCenter.default
            tokens.append(center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.onOpen() }
            })
            tokens.append(center.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main) { [weak self, weak window] _ in
                MainActor.assumeIsolated { if window?.occlusionState.contains(.visible) == true { self?.onOpen() } }
            })
        }
    }
}
