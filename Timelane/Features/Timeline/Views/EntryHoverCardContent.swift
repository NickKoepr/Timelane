import SwiftUI

struct EntryHoverCardContent: View {
    let entry: TimeEntry
    let project: Project?
    let range: DateRange

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let title = entry.title { Text(title).font(.headline).lineLimit(2) }
            HStack(spacing: 6) {
                Circle().fill(project?.color ?? .gray).frame(width: 9, height: 9)
                ProjectNameWithBadge(name: project?.name ?? "Unknown project", customId: project?.customId,
                                     badgeFont: .caption)
                    .font(entry.title == nil ? .headline : .subheadline)
            }
            Text("\(range.start.formatted(date: .omitted, time: .shortened)) – \(range.end.formatted(date: .omitted, time: .shortened))")
                .font(.caption.monospacedDigit())
            Text(DurationFormatter.short(range.duration)).font(.caption).foregroundStyle(.secondary)
            if let note = entry.note, !note.isEmpty {
                Text(note).font(.caption).foregroundStyle(.secondary).lineLimit(3)
            }
        }
    }
}
