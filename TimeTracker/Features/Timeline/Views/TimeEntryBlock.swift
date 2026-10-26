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

    private var primaryText: String {
        entry.title ?? project?.name ?? "Unknown project"
    }

    /// Lines under the first one, in priority order; only as many as fit are shown.
    private var detailLines: [String] {
        var lines: [String] = []
        if entry.title != nil { lines.append(project?.name ?? "Unknown project") }
        lines.append("\(timeText) · \(DurationFormatter.short(duration))")
        if let note = entry.note, !note.isEmpty { lines.append(note) }
        return lines
    }

    private var tooltip: String {
        ([entry.title, project?.name ?? "Unknown project", timeText, entry.note].compactMap { $0 }).joined(separator: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if height >= 15 {
                Text(primaryText).font(height >= 20 ? .caption.weight(.semibold) : .caption2.weight(.semibold)).lineLimit(1)
            }
            ForEach(Array(detailLines.prefix(max(0, Int((height - 18) / 15))).enumerated()), id: \.offset) { _, line in
                Text(line).font(.caption2).lineLimit(1).opacity(0.9)
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
        .help(tooltip)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(primaryText), \(timeText)")
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
