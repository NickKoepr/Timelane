import Foundation

/// The editable values of the time entry window, plus their validation. Pure value type.
struct TimeEntryForm: Equatable {
    enum Mode: Equatable {
        case create
        case edit(TimeEntry)
    }

    let mode: Mode
    var title: String
    var projectId: Int64?
    var start: Date
    var end: Date
    var note: String

    static func new(range: DateRange, projectId: Int64?) -> TimeEntryForm {
        TimeEntryForm(mode: .create, title: "", projectId: projectId, start: range.start, end: range.end, note: "")
    }

    static func editing(_ entry: TimeEntry) -> TimeEntryForm {
        TimeEntryForm(mode: .edit(entry), title: entry.title ?? "", projectId: entry.projectId,
                      start: entry.start, end: entry.end, note: entry.note ?? "")
    }

    var isEditing: Bool { if case .edit = mode { true } else { false } }
    var duration: TimeInterval { end.timeIntervalSince(start) }
    var range: DateRange { DateRange(start: start, end: end) }

    /// Why the form cannot be saved, or nil when the times are fine.
    var timeError: String? {
        if end <= start { return "The end must be after the start." }
        if duration < TimeEntryEditor.minimumDuration { return "An entry must last at least 1 minute." }
        return nil
    }

    var canSave: Bool { projectId != nil && timeError == nil }

    /// The entry to store: new for `.create`, the original with the form's values for `.edit`.
    func makeEntry(now: Date = .now) -> TimeEntry? {
        guard let projectId else { return nil }
        var entry: TimeEntry
        if case .edit(let original) = mode { entry = original } else {
            entry = TimeEntry(projectId: projectId, start: start, end: end, createdAt: now, updatedAt: now)
        }
        entry.projectId = projectId
        entry.start = start
        entry.end = end
        entry.title = TimeEntryEditor.normalized(title)
        entry.note = TimeEntryEditor.normalized(note)
        return entry
    }
}
