import SwiftUI

struct TimeEntryBlock: View {
    let entry: TimeEntry
    let range: DateRange
    let project: Project?
    let height: CGFloat
    let isSelected: Bool
    let canDrag: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
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

    private var projectName: String { project?.name ?? "Unknown project" }

    /// Lines under the first one, in priority order; only as many as fit are shown.
    private var detailLines: [(text: String, isProject: Bool)] {
        var lines: [(String, Bool)] = []
        if entry.title != nil { lines.append((projectName, true)) }
        lines.append(("\(timeText) · \(DurationFormatter.short(duration))", false))
        if let note = entry.note, !note.isEmpty { lines.append((note, false)) }
        return lines
    }

    @ViewBuilder private func line(_ text: String, isProject: Bool, font: Font) -> some View {
        if isProject {
            ProjectNameWithBadge(name: text, customId: project?.customId, style: .onTint, badgeFont: .system(size: 9))
                .font(font)
        } else {
            Text(text).font(font).lineLimit(1)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if height >= 15 {
                line(primaryText, isProject: entry.title == nil,
                     font: height >= 20 ? .caption.weight(.semibold) : .caption2.weight(.semibold))
            }
            ForEach(Array(detailLines.prefix(max(0, Int((height - 18) / 15))).enumerated()), id: \.offset) { _, item in
                line(item.text, isProject: item.isProject, font: .caption2).opacity(0.9)
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
        .contextMenu {
            Button("Edit…", action: onEdit)
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.title ?? project?.titleWithCustomId ?? "Unknown project"), \(timeText)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// A 6pt strip on the top/bottom edge for resizing.
    @ViewBuilder private func handle(_ mode: EntryDragMode) -> some View {
        if canDrag {
            Color.clear
                .frame(height: 6)
                .contentShape(Rectangle())
                .rowResizePointer()
                .gesture(dragGesture(mode))
        }
    }

    private func dragGesture(_ mode: EntryDragMode) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named("timeline"))
            .onChanged { if canDrag { onDrag(mode, $0.translation.height) } }
            .onEnded { _ in if canDrag { onDragEnd() } }
    }
}
