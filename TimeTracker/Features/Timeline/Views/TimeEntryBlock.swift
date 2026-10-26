import SwiftUI

struct TimeEntryBlock: View {
    let entry: TimeEntry
    let project: Project?
    let height: CGFloat

    private var tint: Color { project?.color ?? .gray }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if height > 18 {
                Text(project?.name ?? "Unknown project")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            if height > 34 {
                Text(DurationFormatter.short(entry.duration)).font(.caption2)
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
        .clipped()
        .contentShape(Rectangle())
        .help("\(project?.name ?? "Unknown project")\n\(entry.start.formatted(date: .omitted, time: .shortened)) – \(entry.end.formatted(date: .omitted, time: .shortened))")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(project?.name ?? "Unknown project"), \(DurationFormatter.short(entry.duration))")
    }
}
