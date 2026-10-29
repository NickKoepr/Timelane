import Foundation

/// The id of the entry `AutoTimeLogger` is growing right now (nil when none). The timeline reads it to draw
/// that entry up to its own `now`; the logger is the only writer.
@MainActor @Observable
final class LiveAutoEntry {
    private(set) var entryId: Int64?

    func set(_ id: Int64?) {
        if entryId != id { entryId = id }
    }
}
