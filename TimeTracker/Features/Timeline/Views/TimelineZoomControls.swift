import SwiftUI

typealias ZoomChange = (TimelineZoomState) -> Void

/// "−  level  +" with ⌘− / ⌘+ (also ⌘=) / ⌘0. Changes go through `apply` so the screen can keep the view anchored.
struct TimelineZoomControls: View {
    let zoomState: TimelineZoomState
    let apply: (ZoomChange) -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button { apply { $0.zoomOut() } } label: { Image(systemName: "minus.magnifyingglass") }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(!zoomState.canZoomOut)
                .help("Zoom out (⌘−)")
            Menu(zoomState.zoom.displayName) {
                ForEach(TimelineZoom.allCases, id: \.self) { level in
                    Button(level.displayName) { apply { $0.set(level) } }
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Timeline scale: time per 80 pt")
            Button { apply { $0.zoomIn() } } label: { Image(systemName: "plus.magnifyingglass") }
                .keyboardShortcut("+", modifiers: .command)
                .disabled(!zoomState.canZoomIn)
                .help("Zoom in (⌘+)")
            hiddenShortcuts
        }
    }

    /// ⌘= (same key as ⌘+ on most layouts) and ⌘0 (back to the overview).
    private var hiddenShortcuts: some View {
        Group {
            Button("Zoom in") { apply { $0.zoomIn() } }.keyboardShortcut("=", modifiers: .command)
            Button("Reset zoom") { apply { $0.set(.hour) } }.keyboardShortcut("0", modifiers: .command)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
