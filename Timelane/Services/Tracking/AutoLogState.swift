import Foundation

/// What survives a restart: the logger's own entry and a run that has not written anything yet.
struct AutoLogState: Equatable, Codable, Sendable {
    var entry: AutoLogEntry?
    var pending: AutoLogPending?
}

/// A run of `projectId` that was too short to write an entry. A new run of the same project within
/// `TrackingSettings.mergeGap` after `lastSeen` starts at `start` instead.
struct AutoLogPending: Equatable, Codable, Sendable {
    var projectId: Int64
    var start: Date
    var lastSeen: Date
}
