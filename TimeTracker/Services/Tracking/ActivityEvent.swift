import Foundation

/// Everything that can change what is being tracked. All sources are translated into this enum.
enum ActivityEvent: Equatable, Sendable {
    case appActivated(ForegroundApp)
    /// `at` overrides "now" as the end of the open session (used for idle: the moment input stopped).
    case paused(PauseReason, at: Date? = nil)
    case resumed(PauseReason)
}
