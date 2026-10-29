import SwiftUI

/// Pinch to zoom and anchored scrolling on the timeline scroll view.
/// The pinch comes from an AppKit event monitor (SwiftUI's `MagnifyGesture` does not fire in the menu bar panel).
/// The monitor never consumes events, so the one-finger selection drag and the entry move/resize drags are unaffected.
private struct TimelineZoomBehavior: ViewModifier {
    let viewModel: TimelineViewModel
    @Binding var scrollPosition: ScrollPosition
    let anchor: ZoomScrollAnchor
    let apply: (ZoomChange) -> Void
    @State private var stepper = PinchZoomStepper()

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGSize.self, of: { CGSize(width: $0.contentOffset.y, height: $0.containerSize.height) },
                                    action: { _, new in anchor.visibleAreaChanged(offsetY: new.width, height: new.height) })
            .background {
                MagnifyEventMonitor { delta, phase in
                    if phase.contains(.began) { stepper.reset() }
                    let step = stepper.step(forDelta: delta)
                    if step > 0 { apply { $0.zoomIn() } } else if step < 0 { apply { $0.zoomOut() } }
                    if phase.contains(.ended) || phase.contains(.cancelled) { stepper.reset() }
                }
            }
            // Every animation frame changes the scale; scroll along so the centred time stays put.
            .onChange(of: viewModel.zoomState.pointsPerHour) {
                guard let offset = anchor.offset(with: viewModel.geometry) else { return }
                scrollPosition.scrollTo(y: offset)
                guard !viewModel.zoomState.isAnimating else { return }
                anchor.finish()
                // Once more after layout: zooming in near the end of the day can be clamped to the old height.
                Task { @MainActor in scrollPosition.scrollTo(y: offset) }
            }
    }
}

extension View {
    func timelineZoom(viewModel: TimelineViewModel, scrollPosition: Binding<ScrollPosition>, anchor: ZoomScrollAnchor,
                      apply: @escaping (ZoomChange) -> Void) -> some View {
        modifier(TimelineZoomBehavior(viewModel: viewModel, scrollPosition: scrollPosition, anchor: anchor, apply: apply))
    }
}
