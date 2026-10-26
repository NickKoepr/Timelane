import Foundation

/// The current zoom level of the timeline; the last level is remembered.
/// `pointsPerHour` is the scale that is drawn: it follows `zoom`, animated when `animationDuration` > 0.
@MainActor @Observable
final class TimelineZoomState {
    static let defaultKey = "timelineZoomLevel"
    private let defaults: UserDefaults
    private let key: String
    private(set) var zoom: TimelineZoom
    private(set) var pointsPerHour: CGFloat
    private(set) var isAnimating = false
    /// 0 changes the scale at once (tests, Reduce Motion).
    var animationDuration: TimeInterval = 0

    @ObservationIgnored private var animation: Task<Void, Never>?

    /// `key` is where the level is remembered; use another key for a second timeline (menu bar) so they stay independent.
    /// `defaultLevel` applies until a level has been saved.
    init(defaults: UserDefaults = .standard, key: String = TimelineZoomState.defaultKey, defaultLevel: TimelineZoom = .hour) {
        self.defaults = defaults
        self.key = key
        let saved = defaults.object(forKey: key) == nil ? defaultLevel : TimelineZoom(rawValue: defaults.integer(forKey: key)) ?? defaultLevel
        zoom = saved
        pointsPerHour = saved.pointsPerHour
    }

    var canZoomIn: Bool { zoom < .tenMinutes }
    var canZoomOut: Bool { zoom > .hour }

    func zoomIn() { set(zoom.zoomedIn()) }
    func zoomOut() { set(zoom.zoomedOut()) }

    func set(_ newZoom: TimelineZoom) {
        zoom = newZoom
        defaults.set(newZoom.rawValue, forKey: key)
        animateScale(to: newZoom.pointsPerHour)
    }

    /// Steps the drawn scale towards `target`; a new change continues from wherever the previous one was.
    private func animateScale(to target: CGFloat) {
        animation?.cancel()
        let transition = ZoomTransition(from: pointsPerHour, to: target, duration: animationDuration)
        guard transition.from != target, !transition.isFinished(after: 0) else {
            isAnimating = false
            pointsPerHour = target
            return
        }
        isAnimating = true
        animation = Task { [weak self] in
            let start = ContinuousClock.now
            while !Task.isCancelled {
                let elapsed = (ContinuousClock.now - start) / .seconds(1)
                let finished = transition.isFinished(after: elapsed)
                if finished { self?.isAnimating = false }
                self?.pointsPerHour = transition.pointsPerHour(after: elapsed)
                if finished { return }
                try? await Task.sleep(for: .milliseconds(8))
            }
        }
    }
}
