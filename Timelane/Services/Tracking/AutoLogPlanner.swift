import Foundation

/// A linked app being in the foreground: `projectId` gets an entry from `start` on.
struct AutoLogRun: Equatable, Sendable {
    var projectId: Int64
    var start: Date
}

/// The entry the logger wrote (and may keep growing).
struct AutoLogEntry: Equatable, Sendable {
    var id: Int64
    var projectId: Int64
    var start: Date
    var lastEnd: Date
}

enum AutoLogAction: Equatable, Sendable {
    case nothing
    case create(DateRange)
    /// Set the end of the logger's own entry (also used to shrink it when idle time ends a run).
    case setEnd(Date)
    /// The entry was changed by the user: forget it and, while the run goes on, start over from now.
    case restart
    /// The entry was only created by idle time at the end of a run: remove it.
    case delete
}

/// Pure decision logic of `AutoTimeLogger`: given the state and the time, what should happen?
///
/// Invariant: the logger only ever changes the end of its own entry for the current run. It never changes
/// the project of an existing entry and never touches time recorded before the current run (except
/// continuing its own entry across a small gap of the same project).
enum AutoLogPlanner {
    static func plan(run: AutoLogRun, entry: AutoLogEntry?, entryIsIntact: Bool, now: Date, isFinal: Bool = false) -> AutoLogAction {
        // The session ended in the past (idle): remove the idle time from the entry grown in this run.
        // Only time of this run is removed; `now >= run.start`, so earlier data stays as it was.
        if isFinal, entryIsIntact, let entry, entry.projectId == run.projectId,
           entry.lastEnd > run.start, now < entry.lastEnd {
            return now.timeIntervalSince(entry.start) >= TimeEntryEditor.minimumDuration ? .setEnd(now) : .delete
        }
        // Short visits (quick ⌘-Tab) never create an entry.
        guard now.timeIntervalSince(run.start) >= TimeEntryEditor.minimumDuration else { return .nothing }
        if let entry, entry.projectId == run.projectId {
            if entry.lastEnd > run.start {
                // Grown during this run: keep growing it unless the user touched it.
                return entryIsIntact ? extend(entry, to: now) : .restart
            }
            // Written by an earlier run: continue it when the gap is small.
            if entryIsIntact, run.start.timeIntervalSince(entry.lastEnd) <= TrackingSettings.autoLogMergeGap {
                return extend(entry, to: now)
            }
        }
        return .create(DateRange(start: run.start, end: now))
    }

    private static func extend(_ entry: AutoLogEntry, to end: Date) -> AutoLogAction {
        guard end != entry.lastEnd, end.timeIntervalSince(entry.start) >= TimeEntryEditor.minimumDuration else { return .nothing }
        return .setEnd(end)
    }
}
