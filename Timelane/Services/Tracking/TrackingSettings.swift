import Foundation

/// Centralized tracking constants (candidates for a future settings screen).
enum TrackingSettings {
    static let idleThreshold: TimeInterval = 5 * 60
    static let idleCheckInterval: TimeInterval = 30
    static let heartbeatInterval: TimeInterval = 60
    /// How often the entry of a linked app grows while the app is in use.
    static let autoLogInterval: TimeInterval = 5
    /// Same-app sessions closer than this are drawn as one block, and an automatic entry of the same
    /// project continues across a gap this small.
    static let mergeGap: TimeInterval = 60
    /// Shorter app blocks are not drawn, and shorter automatic runs never create an entry.
    /// `TimeEntryEditor.minimumDuration` must stay equal (checked by a test).
    static let minimumBlockDuration: TimeInterval = 60
}
