import Foundation

/// Makes entries that overlap after a sync batch non-overlapping again, deterministically.
///
/// Entries are placed newest action first (`actionTime`, tiebreak larger `syncId`); each next entry
/// is clipped by everything already placed: fully covered is deleted, partly covered is trimmed, and
/// an entry with something placed in its middle is split. The first piece keeps the `syncId`; extra
/// pieces get a `DeterministicUUID` derived from the parent and the piece start, so every device
/// creates identical rows. Timestamps are never touched. Entries are plain intervals, so an entry
/// across midnight needs no special treatment: pass in every entry that touches the affected days.
enum TimeEntrySettler {
    static func settle(_ entries: [SyncSettlerEntry]) -> TimeEntrySettlement {
        let ordered = entries.sorted { lhs, rhs in
            if lhs.fields.actionTime != rhs.fields.actionTime { return lhs.fields.actionTime > rhs.fields.actionTime }
            return lhs.syncId.uuidString > rhs.syncId.uuidString
        }

        var placed: [(start: Date, end: Date)] = []
        var final: [UUID: SyncSettlerEntry] = [:]
        for entry in ordered {
            var pieces = [(start: entry.fields.start, end: entry.fields.end)]
            for taken in placed { pieces = pieces.flatMap { subtract(taken, from: $0) } }
            pieces.sort { $0.start < $1.start }

            for (index, piece) in pieces.enumerated() {
                var result = entry
                result.fields.start = piece.start
                result.fields.end = piece.end
                if index > 0 {
                    let name = "\(entry.syncId.uuidString):split:\(piece.start.timeIntervalSince1970)"
                    result.syncId = DeterministicUUID.make(from: name)
                }
                if final[result.syncId] == nil { final[result.syncId] = result }
                placed.append(piece)
            }
        }

        let original = Dictionary(entries.map { ($0.syncId, $0) }, uniquingKeysWith: { first, _ in first })
        let saves = final.values.filter { original[$0.syncId] != $0 }
            .sorted { $0.syncId.uuidString < $1.syncId.uuidString }
        let deletes = original.keys.filter { final[$0] == nil }.sorted { $0.uuidString < $1.uuidString }
        return TimeEntrySettlement(saves: saves, deletes: deletes)
    }

    /// The parts of `piece` that `taken` does not cover.
    private static func subtract(_ taken: (start: Date, end: Date), from piece: (start: Date, end: Date))
        -> [(start: Date, end: Date)] {
        guard taken.start < piece.end, piece.start < taken.end else { return [piece] }
        var parts: [(start: Date, end: Date)] = []
        if piece.start < taken.start { parts.append((piece.start, taken.start)) }
        if taken.end < piece.end { parts.append((taken.end, piece.end)) }
        return parts
    }
}
