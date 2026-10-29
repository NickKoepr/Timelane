import Foundation

/// Shows the running automatic entry up to `now`, the same moment that ends the open app session,
/// so both lanes change minute label in the same frame. The stored row is not touched.
enum LiveEntryProjection {
    static func displayed(_ entries: [TimeEntry], liveEntryId: Int64?, now: Date) -> [TimeEntry] {
        guard let liveEntryId, let index = entries.firstIndex(where: { $0.id == liveEntryId }) else { return entries }
        var live = entries[index]
        guard live.end < now else { return entries }
        // Entries never overlap: stop at the next stored entry that starts after the live one.
        let limit = entries.filter { $0.id != liveEntryId && $0.start >= live.start }.map(\.start).min()
        live.end = min(now, limit ?? now)
        guard live.end > entries[index].end else { return entries }
        var result = entries
        result[index] = live
        return result
    }
}
