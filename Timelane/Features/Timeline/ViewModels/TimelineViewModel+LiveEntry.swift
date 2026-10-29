import Foundation

/// The running automatic entry is displayed up to `now` (like the open session); edits use the stored row.
extension TimelineViewModel {
    /// The entries as drawn: the live automatic entry is extended to `now` (today only).
    var entries: [TimeEntry] {
        guard isToday else { return storedEntries }
        return LiveEntryProjection.displayed(storedEntries, liveEntryId: liveAutoEntry.entryId, now: now)
    }

    /// The row as stored, for editing, dragging and deleting (never a projected end).
    func stored(_ entry: TimeEntry) -> TimeEntry {
        storedEntries.first { $0.id == entry.id } ?? entry
    }

    /// Keeps `now` current while viewing today; one value feeds sessions, totals and the projection.
    func tick() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(TrackingSettings.autoLogInterval))
            guard !Task.isCancelled else { return }
            guard isToday else { continue }
            refreshNow()
        }
    }
}
