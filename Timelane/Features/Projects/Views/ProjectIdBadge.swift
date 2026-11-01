import SwiftUI

/// Small monospaced badge with a project's custom ID; renders nothing without one.
struct ProjectIdBadge: View {
    enum Style { case standard, onTint }

    let customId: String?
    var style: Style = .standard
    var font: Font = .caption2

    var body: some View {
        if let customId {
            Text(customId)
                .font(font.monospaced())
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(style == .onTint ? Color.white : Color.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(style == .onTint ? Color.white.opacity(0.22) : Color.primary.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 4))
                .accessibilityLabel("ID \(customId)")
        }
    }
}

/// Project name (truncating) followed by its ID badge (never truncated).
struct ProjectNameWithBadge: View {
    let name: String
    let customId: String?
    var style: ProjectIdBadge.Style = .standard
    var badgeFont: Font = .caption2

    var body: some View {
        HStack(spacing: 5) {
            Text(name).lineLimit(1).truncationMode(.tail)
            ProjectIdBadge(customId: customId, style: style, font: badgeFont)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        ProjectNameWithBadge(name: "Website", customId: "ACME-042")
        ProjectNameWithBadge(name: "Website", customId: nil)
        ProjectNameWithBadge(name: "Website", customId: "P2026.17", style: .onTint)
            .padding(6).background(Color.blue, in: RoundedRectangle(cornerRadius: 5)).foregroundStyle(.white)
    }
    .padding()
}
