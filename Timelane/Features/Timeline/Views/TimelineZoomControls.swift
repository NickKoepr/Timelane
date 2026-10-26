import SwiftUI

typealias ZoomChange = (TimelineZoomState) -> Void

/// "−  level  +" with ⌘− / ⌘+ (also ⌘=) / ⌘0. Changes go through `apply` so the screen can keep the view anchored.
struct TimelineZoomControls: View {
    let zoomState: TimelineZoomState
    let apply: (ZoomChange) -> Void
    /// False when the owner registers the shortcuts once via `TimelineZoomShortcuts` (e.g. inside `ViewThatFits`).
    var registersShortcuts = true

    var body: some View {
        HStack(spacing: 4) {
            Button { apply { $0.zoomOut() } } label: { Image(systemName: "minus.magnifyingglass") }
                .keyboardShortcutIf(registersShortcuts, "-")
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
                .keyboardShortcutIf(registersShortcuts, "+")
                .disabled(!zoomState.canZoomIn)
                .help("Zoom in (⌘+)")
            if registersShortcuts { TimelineZoomShortcuts(apply: apply) }
        }
    }
}
