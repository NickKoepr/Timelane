import SwiftUI

/// Pinch to zoom and anchored scrolling on the timeline scroll view.
/// The pinch is a simultaneous gesture on the scroll view only: it never competes with the one-finger
/// selection drag or the entry move/resize drags on the blocks.
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
            .simultaneousGesture(MagnifyGesture()
                .onChanged { value in
                    let step = stepper.step(for: value.magnification)
                    if step > 0 { apply { $0.zoomIn() } } else if step < 0 { apply { $0.zoomOut() } }
                }
                .onEnded { _ in stepper.reset() })
            .onChange(of: viewModel.zoomState.zoom) {
                guard let offset = anchor.takeOffset(with: viewModel.geometry) else { return }
                // Wait for the new content height, otherwise the offset is clamped to the old one.
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
