#if DEBUG
import CoreGraphics

/// One App Store screenshot: which screen the app shows before it captures itself.
enum ScreenshotScene: String, CaseIterable, Sendable {
    case timeline
    case entryForm
    case menuBar
    case projects
    case overview
    case trackedApps
    case settings

    /// Main window size in points (2× in the capture); list screens are shorter so they don't look empty.
    var windowSize: CGSize {
        switch self {
        case .projects, .trackedApps: CGSize(width: 1240, height: 600)
        default: CGSize(width: 1240, height: 880)
        }
    }

    /// Screen of the main window behind the scene.
    var sidebarItem: SidebarItem {
        switch self {
        case .timeline, .entryForm, .menuBar, .settings: .timeline
        case .projects: .projects
        case .overview: .overview
        case .trackedApps: .trackedApps
        }
    }
}
#endif
