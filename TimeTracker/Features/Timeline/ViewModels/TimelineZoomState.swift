import Foundation

/// The current zoom level of the timeline; the last level is remembered.
@MainActor @Observable
final class TimelineZoomState {
    private static let key = "timelineZoomLevel"
    private let defaults: UserDefaults
    private(set) var zoom: TimelineZoom

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        zoom = TimelineZoom(rawValue: defaults.integer(forKey: Self.key)) ?? .hour
    }

    var canZoomIn: Bool { zoom < .tenMinutes }
    var canZoomOut: Bool { zoom > .hour }

    func zoomIn() { set(zoom.zoomedIn()) }
    func zoomOut() { set(zoom.zoomedOut()) }

    func set(_ newZoom: TimelineZoom) {
        zoom = newZoom
        defaults.set(newZoom.rawValue, forKey: Self.key)
    }
}
