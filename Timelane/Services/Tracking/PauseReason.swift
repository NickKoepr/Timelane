import Foundation

/// Why tracking is paused. Tracking resumes only when every reason is cleared.
enum PauseReason: Hashable, Sendable {
    case sleep
    case screenOff
    case sessionInactive
    case locked
    case idle
}
