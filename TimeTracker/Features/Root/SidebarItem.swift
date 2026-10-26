import Foundation

enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case timeline
    case projects

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timeline: "Timeline"
        case .projects: "Projects"
        }
    }

    var systemImage: String {
        switch self {
        case .timeline: "calendar.day.timeline.left"
        case .projects: "folder"
        }
    }
}
