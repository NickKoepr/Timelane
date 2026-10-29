import Foundation

/// What the menu bar item shows: the plain clock, or the clock with a red recording dot.
enum MenuBarIconStyle: Equatable {
    case normal, recording

    init(isRecording: Bool) { self = isRecording ? .recording : .normal }

    /// Accessibility / tooltip title of the menu bar item.
    var title: String { self == .recording ? "Timelane – Recording" : "Timelane" }
}
