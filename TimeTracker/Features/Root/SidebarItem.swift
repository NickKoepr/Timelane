import Foundation

enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case timeline
    case projects
    case trackedApps

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timeline: "Timeline"
        case .projects: "Projects"
        case .trackedApps: "Tracked Apps"
        }
    }

    var systemImage: String {
        switch self {
        case .timeline: "calendar.day.timeline.left"
        case .projects: "folder"
        case .trackedApps: "app.badge.checkmark"
        }
    }
}
