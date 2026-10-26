import Foundation

/// Pure idle state machine: feed it the seconds since the last input event.
struct IdleDetector {
    let threshold: TimeInterval
    private(set) var isIdle = false

    init(threshold: TimeInterval = TrackingSettings.idleThreshold) {
        self.threshold = threshold
    }

    mutating func evaluate(idleSeconds: TimeInterval, now: Date) -> ActivityEvent? {
        if !isIdle, idleSeconds >= threshold {
            isIdle = true
            return .paused(.idle, at: now.addingTimeInterval(-idleSeconds))
        }
        if isIdle, idleSeconds < threshold {
            isIdle = false
            return .resumed(.idle)
        }
        return nil
    }
}
