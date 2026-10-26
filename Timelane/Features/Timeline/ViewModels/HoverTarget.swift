import Foundation

/// What the pointer is over on the timeline.
enum HoverTarget {
    case session(AppSessionBlockModel)
    /// `range` is the displayed range (differs from the stored one while dragging).
    case entry(TimeEntry, project: Project?, range: DateRange)

    var id: String {
        switch self {
        case .session(let block): "session-\(block.id)"
        case .entry(let entry, _, _): "entry-\(entry.id.map(String.init) ?? "new")"
        }
    }

    /// Entries are on the right: their card opens to the left, over the app lane. Sessions the other way round.
    var cardOpensToLeft: Bool {
        if case .entry = self { true } else { false }
    }

    /// Rough height, used only to keep the card inside the visible area.
    var estimatedCardHeight: CGFloat {
        if case .entry(let entry, _, _) = self { entry.note?.isEmpty == false ? 130 : 100 }
        else { 72 }
    }
}
