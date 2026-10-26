import SwiftUI

/// Lane with the registered time. Entries sit on top of the gesture layer in `TimelineColumn`, so their own move/resize gestures win.
struct TimeEntryLane: View {
    let viewModel: TimelineViewModel

    var body: some View {
        let geometry = viewModel.geometry
        ZStack(alignment: .topLeading) {
            Color.clear
            ForEach(viewModel.entries) { entry in
                block(for: entry, geometry: geometry)
            }
            SelectionOverlay(viewModel: viewModel)
        }
        .frame(height: geometry.totalHeight)
    }

    private func block(for entry: TimeEntry, geometry: TimelineGeometry) -> some View {
        let editing = viewModel.entryEditing
        let range = editing.displayRange(for: entry)
        let frame = geometry.frame(for: range.start, end: range.end)
        return TimeEntryBlock(
            entry: entry, range: range, project: viewModel.project(id: entry.projectId),
            height: max(frame.height - 1, 2),
            isSelected: editing.selectedEntryId == entry.id,
            canDrag: editing.canDrag(entry, in: geometry),
            onTap: { viewModel.select(entry) },
            onDrag: { mode, dy in editing.dragChanged(entry, mode: mode, translationY: dy, geometry: geometry) },
            onDragEnd: { Task { await editing.dragEnded(entry) } })
        .offset(y: frame.y)
    }
}
