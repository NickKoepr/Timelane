import SwiftUI

struct TimeEntryBlock: View {
    let entry: TimeEntry
    let range: DateRange
    let project: Project?
    let height: CGFloat
    let isSelected: Bool
    let canDrag: Bool
    let onTap: () -> Void
    let onDrag: (EntryDragMode, CGFloat) -> Void
    let onDragEnd: () -> Void

    private var tint: Color { project?.color ?? .gray }
    private var duration: TimeInterval { range.duration }
    private var timeText: String {
        "\(range.start.formatted(date: .omitted, time: .shortened)) – \(range.end.formatted(date: .omitted, time: .shortened))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if height > 18 {
                Text(project?.name ?? "Unknown project").font(.caption.weight(.semibold)).lineLimit(1)
            }
            if height > 34 {
                Text("\(timeText) · \(DurationFormatter.short(duration))").font(.caption2).lineLimit(1)
            }
            if height > 50, let note = entry.note, !note.isEmpty {
                Text(note).font(.caption2).lineLimit(2).opacity(0.85)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
        .background(tint.opacity(0.9), in: RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.primary, lineWidth: isSelected ? 2 : 0))
        .clipped()
        .overlay(alignment: .top) { handle(.resizeTop) }
        .overlay(alignment: .bottom) { handle(.resizeBottom) }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .gesture(dragGesture(.move))
        .help("\(project?.name ?? "Unknown project")\n\(timeText)")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(project?.name ?? "Unknown project"), \(timeText)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// A 6pt strip on the top/bottom edge for resizing.
    @ViewBuilder private func handle(_ mode: EntryDragMode) -> some View {
        if canDrag {
            Color.clear
                .frame(height: 6)
                .contentShape(Rectangle())
                .pointerStyle(.rowResize)
                .gesture(dragGesture(mode))
        }
    }

    private func dragGesture(_ mode: EntryDragMode) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named("timeline"))
            .onChanged { if canDrag { onDrag(mode, $0.translation.height) } }
            .onEnded { _ in if canDrag { onDragEnd() } }
    }
}
