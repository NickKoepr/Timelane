import Foundation

/// Centralized tracking constants (candidates for a future settings screen).
enum TrackingSettings {
    static let idleThreshold: TimeInterval = 5 * 60
    static let idleCheckInterval: TimeInterval = 30
    static let heartbeatInterval: TimeInterval = 60
    /// How often the entry of a linked app grows while the app is in use.
    static let autoLogInterval: TimeInterval = 5
    /// A new automatic entry within this gap after the previous one (same project) extends it instead.
    static let autoLogMergeGap: TimeInterval = 2 * 60
}
