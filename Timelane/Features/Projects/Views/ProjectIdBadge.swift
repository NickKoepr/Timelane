import SwiftUI

/// Small monospaced badge with a project's custom ID; renders nothing without one.
struct ProjectIdBadge: View {
    enum Style { case standard, onTint }

    let customId: String?
    var style: Style = .standard
    var font: Font = .caption2
    /// `nil` shows the whole ID (Projects screen); elsewhere long IDs are shortened.
    var maxLength: Int? = ProjectCustomId.displayLength

    var body: some View {
        if let customId {
            Text(maxLength.map { ProjectCustomId.shortened(customId, to: $0) } ?? customId)
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

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        ProjectIdBadge(customId: "ACME-042")
        ProjectIdBadge(customId: "P2026.17", style: .onTint)
            .padding(6).background(Color.blue, in: RoundedRectangle(cornerRadius: 5))
    }
    .padding()
}
