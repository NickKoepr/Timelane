import CoreGraphics

/// How much of an app session block's label fits. Thresholds match the `.caption` / `.caption2` line heights.
enum SessionLabelStyle: Equatable {
    case full          // icon + name + duration on two lines
    case singleLine    // icon + name on one line
    case iconOnly      // just the icon (10–14 pt)
    case colorOnly     // just the coloured bar

    static let fullHeight: CGFloat = 32
    static let singleLineHeight: CGFloat = 15
    static let iconHeight: CGFloat = 10
    /// Below this width the name is dropped; below `minimumIconWidth` nothing but the bar is left.
    static let minimumNameWidth: CGFloat = 60
    static let minimumIconWidth: CGFloat = 24

    static func style(forHeight height: CGFloat, width: CGFloat) -> SessionLabelStyle {
        guard height >= iconHeight, width >= minimumIconWidth else { return .colorOnly }
        guard width >= minimumNameWidth else { return .iconOnly }
        if height >= fullHeight { return .full }
        return height >= singleLineHeight ? .singleLine : .iconOnly
    }
}
