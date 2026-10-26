import Foundation

/// Selecting, moving, resizing, editing and deleting existing time entries.
@MainActor @Observable
final class EntryEditingViewModel {
    private(set) var selectedEntryId: Int64?
    private(set) var detail: TimeEntryDetailViewModel?
    private(set) var preview: EntryDragPreview?
    var errorMessage: String?

    private let editor: TimeEntryEditor

    init(editor: TimeEntryEditor) { self.editor = editor }

    static let minimumDuration: TimeInterval = 5 * 60

    /// Where to draw an entry: its stored range, or the live drag position.
    func displayRange(for entry: TimeEntry) -> DateRange {
        preview?.entryId == entry.id ? preview?.range ?? entry.range : entry.range
    }

    func isShowingDetail(for entry: TimeEntry) -> Bool { detail?.entry.id == entry.id }

    // MARK: Selection

    func select(_ entry: TimeEntry, projects: [Project]) {
        selectedEntryId = entry.id
        detail = TimeEntryDetailViewModel(entry: entry, projects: projects, editor: editor,
                                          onFinish: { [weak self] in self?.detail = nil })
    }

    func closeDetail() { detail = nil }

    func deselect() {
        selectedEntryId = nil
        detail = nil
    }

    func reset() {
        deselect()
        preview = nil
    }

    // MARK: Drag

    /// Entries that extend past the day edges can only be edited through the popover.
    func canDrag(_ entry: TimeEntry, in geometry: TimelineGeometry) -> Bool {
        entry.start >= geometry.day.start && entry.end <= geometry.day.end
    }

    func dragChanged(_ entry: TimeEntry, mode: EntryDragMode, translationY: CGFloat, geometry: TimelineGeometry) {
        guard let id = entry.id, canDrag(entry, in: geometry) else { return }
        detail = nil
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
