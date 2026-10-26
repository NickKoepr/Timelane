import SwiftUI

/// Lane with the registered time. Dragging on empty space selects a range to register.
struct TimeEntryLane: View {
    let viewModel: TimelineViewModel

    var body: some View {
        let geometry = viewModel.geometry
        ZStack(alignment: .topLeading) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { viewModel.entryEditing.deselect() }
                .gesture(selectionDrag)
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
        .popover(isPresented: detailBinding(for: entry), arrowEdge: .leading) {
            if let detail = editing.detail { TimeEntryDetailPopover(viewModel: detail) }
        }
    }

    private func detailBinding(for entry: TimeEntry) -> Binding<Bool> {
        Binding(get: { viewModel.entryEditing.isShowingDetail(for: entry) },
                set: { if !$0 { viewModel.entryEditing.closeDetail() } })
    }

    private var selectionDrag: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("timeline"))
            .onChanged { viewModel.updateSelection(startY: $0.startLocation.y, currentY: $0.location.y) }
            .onEnded { _ in viewModel.finishSelection() }
    }
}
