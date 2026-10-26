import Foundation

/// Result of making room for an entry: what to save (insert or update) and what to delete.
struct OverlapResolution: Equatable {
    var toSave: [TimeEntry]
    var toDelete: [Int64]
}

/// Entries on the timeline never overlap; the newest action wins.
enum TimeEntryOverlapResolver {
    /// `entry` is new (`id == nil`) or an existing entry that was changed.
    /// Other entries are covered (deleted), trimmed on one side, or split around it.
    static func resolve(existing: [TimeEntry], applying entry: TimeEntry, now: Date) -> OverlapResolution {
        var result = OverlapResolution(toSave: [entry], toDelete: [])

        for other in existing where other.id == nil || other.id != entry.id {
            guard other.start < entry.end, entry.start < other.end else { continue }

            let startsBefore = other.start < entry.start
            let endsAfter = other.end > entry.end

            switch (startsBefore, endsAfter) {
            case (false, false):                       // fully covered
                if let id = other.id { result.toDelete.append(id) }
            case (true, true):                         // split around the new entry
                var head = other
                head.end = entry.start
                head.updatedAt = now
                var tail = other
                tail.id = nil
                tail.start = entry.end
                tail.createdAt = now
                tail.updatedAt = now
                result.toSave += [head, tail]
            case (true, false):                        // overlaps the other's end
                var trimmed = other
                trimmed.end = entry.start
                trimmed.updatedAt = now
                result.toSave.append(trimmed)
            case (false, true):                        // overlaps the other's start
                var trimmed = other
                trimmed.start = entry.end
                trimmed.updatedAt = now
                result.toSave.append(trimmed)
            }
        }
        return result
    }
}
