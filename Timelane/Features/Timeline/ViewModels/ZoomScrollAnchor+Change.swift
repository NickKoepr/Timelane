import Foundation

extension ZoomScrollAnchor {
    /// Applies a zoom change (animated unless `animated` is false) and keeps the time in the middle of the view in place.
    func change(_ change: ZoomChange, in viewModel: TimelineViewModel, animated: Bool) {
        capture(with: viewModel.geometry)
        viewModel.zoomState.animationDuration = animated ? ZoomTransition.defaultDuration : 0
        change(viewModel.zoomState)
    }
}
