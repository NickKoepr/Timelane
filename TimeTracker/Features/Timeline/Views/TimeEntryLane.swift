import SwiftUI

struct TimeEntryLane: View {
    let entries: [TimeEntry]
    let geometry: TimelineGeometry
    let project: (Int64) -> Project?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            ForEach(entries) { entry in
                let frame = geometry.frame(for: entry.start, end: entry.end)
                TimeEntryBlock(entry: entry, project: project(entry.projectId), height: max(frame.height - 1, 2))
                    .offset(y: frame.y)
            }
        }
        .frame(height: geometry.totalHeight)
    }
}
