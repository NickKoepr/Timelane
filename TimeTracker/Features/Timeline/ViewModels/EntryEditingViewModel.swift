import Foundation

/// Selecting, moving, resizing, editing and deleting existing time entries.
@MainActor @Observable
final class EntryEditingViewModel {
    private(set) var selectedEntryId: Int64?
    private(set) var preview: EntryDragPreview?
    var errorMessage: String?

    private let editor: TimeEntryEditor

    init(editor: TimeEntryEditor) { self.editor = editor }

    static let minimumDuration: TimeInterval = 5 * 60

    /// Where to draw an entry: its stored range, or the live drag position.
    func displayRange(for entry: TimeEntry) -> DateRange {
        preview?.entryId == entry.id ? preview?.range ?? entry.range : entry.range
    }

    // MARK: Selection

    func select(_ entry: TimeEntry) { selectedEntryId = entry.id }

    func deselect() { selectedEntryId = nil }

    func reset() {
        deselect()
        preview = nil
    }

    // MARK: Drag

    /// Entries that extend past the day edges can only be edited through the time entry window.
    func canDrag(_ entry: TimeEntry, in geometry: TimelineGeometry) -> Bool {
        entry.start >= geometry.day.start && entry.end <= geometry.day.end
    }

    func dragChanged(_ entry: TimeEntry, mode: EntryDragMode, translationY: CGFloat, geometry: TimelineGeometry) {
        guard let id = entry.id, canDrag(entry, in: geometry) else { return }
        selectedEntryId = id
        preview = EntryDragPreview(entryId: id, range: EntryDragCalculator.range(
            for: mode, original: entry.range, translationY: translationY,
            geometry: geometry, minimumDuration: Self.minimumDuration))
    }

    func dragEnded(_ entry: TimeEntry) async {
        guard let preview, preview.entryId == entry.id else { return }
        defer { self.preview = nil }
        guard preview.range != entry.range else { return }
        var changed = entry
        changed.start = preview.range.start
        changed.end = preview.range.end
        await perform { try await editor.update(changed) }
    }

    // MARK: Delete

    func delete(_ entry: TimeEntry) async {
        await perform { try await editor.delete(entry) }
        deselect()
    }

    private func perform(_ work: () async throws -> Void) async {
        do { try await work() } catch { errorMessage = error.localizedDescription }
    }
}
