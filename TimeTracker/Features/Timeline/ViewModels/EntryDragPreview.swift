import Foundation

/// The in-progress position of an entry that is being moved or resized.
struct EntryDragPreview: Equatable {
    let entryId: Int64
    let range: DateRange
}
