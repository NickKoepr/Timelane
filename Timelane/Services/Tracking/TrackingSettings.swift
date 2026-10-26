import Foundation

/// Centralized tracking constants (candidates for a future settings screen).
enum TrackingSettings {
    static let idleThreshold: TimeInterval = 5 * 60
    static let idleCheckInterval: TimeInterval = 30
    static let heartbeatInterval: TimeInterval = 60
}
