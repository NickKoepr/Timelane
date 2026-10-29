import SwiftUI

extension ActivityLevel {
    /// Square color: neutral for no hours, the accent color in four steps otherwise (light and dark mode).
    var color: Color {
        switch self {
        case .none: Color.primary.opacity(0.08)
        case .low: Color.accentColor.opacity(0.35)
        case .medium: Color.accentColor.opacity(0.55)
        case .high: Color.accentColor.opacity(0.78)
        case .max: Color.accentColor
        }
    }
}
