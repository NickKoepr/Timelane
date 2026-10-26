import SwiftUI

/// Lane with the registered time. Dragging on empty space selects a range to register.
struct TimeEntryLane: View {
    let viewModel: TimelineViewModel

    var body: some View {
        let geometry = viewModel.geometry
        ZStack(alignment: .topLeading) {
            Color.clear
                .contentShape(Rectangle())
                .gesture(selectionDrag)
            ForEach(viewModel.entries) { entry in
                let frame = geometry.frame(for: entry.start, end: entry.end)
                TimeEntryBlock(entry: entry, project: viewModel.project(id: entry.projectId),
                               height: max(frame.height - 1, 2))
                    .offset(y: frame.y)
            }
            SelectionOverlay(viewModel: viewModel)
        }
        .frame(height: geometry.totalHeight)
    }

    private var selectionDrag: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("timeline"))
            .onChanged { viewModel.updateSelection(startY: $0.startLocation.y, currentY: $0.location.y) }
            .onEnded { _ in viewModel.finishSelection() }
    }
}
