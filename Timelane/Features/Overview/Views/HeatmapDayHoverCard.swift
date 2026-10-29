import SwiftUI

/// The card next to the hovered heatmap square. Drawn once as an overlay of the heatmap; it never takes
/// hits, so clicks go straight through to the squares. (No `.popover`, same as `TimelineHoverCard`.)
struct HeatmapDayHoverCard: View {
    static let width: CGFloat = 220

    let detail: OverviewDayDetail
    let squareFrame: CGRect
    let heatmapWidth: CGFloat

    var body: some View {
        let origin = HoverCardPlacement.origin(
            for: squareFrame, opensToLeft: squareFrame.midX > heatmapWidth / 2,
            cardSize: CGSize(width: Self.width, height: estimatedHeight),
            columnWidth: heatmapWidth, columnHeight: .greatestFiniteMagnitude, minX: 0,
            visibleTop: 0, visibleBottom: .greatestFiniteMagnitude)
        HeatmapDayHoverCardContent(detail: detail)
            .padding(10)
            .frame(width: Self.width, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.12)))
            .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
            .offset(x: origin.x, y: origin.y)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var estimatedHeight: CGFloat { 44 + 18 * CGFloat(detail.rows.count) }
}

#Preview {
    let detail = OverviewDayDetail(day: .now, secondsByProject: [1: 7200], projects: [
        Project(id: 1, name: "Alpha", colorHex: "#4F8EF7"),
    ], highlightedProjectId: nil)
    return HeatmapDayHoverCard(detail: detail, squareFrame: CGRect(x: 20, y: 20, width: 12, height: 12), heatmapWidth: 400)
        .frame(width: 400, height: 150, alignment: .topLeading)
}
