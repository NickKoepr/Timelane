import SwiftUI

/// Project name (truncating) followed by its ID badge (never truncated).
struct ProjectNameWithBadge: View {
    let name: String
    let customId: String?
    var style: ProjectIdBadge.Style = .standard
    var badgeFont: Font = .caption2
    var badgeMaxLength: Int? = ProjectCustomId.displayLength

    var body: some View {
        HStack(spacing: 5) {
            Text(name).lineLimit(1).truncationMode(.tail)
            ProjectIdBadge(customId: customId, style: style, font: badgeFont, maxLength: badgeMaxLength)
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
