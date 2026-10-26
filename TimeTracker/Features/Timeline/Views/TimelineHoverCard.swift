import SwiftUI

/// The card next to the hovered block. Drawn once as an overlay of the timeline column; it never takes
/// hits, so clicks and drags go straight through to the blocks and the background underneath.
/// (A `.popover` is not used: popovers on offset views were the v1 bug.)
struct TimelineHoverCard: View {
    static let width: CGFloat = 220

    let target: HoverTarget
    let blockFrame: CGRect
    let columnSize: CGSize
    let visibleTop: CGFloat
    let visibleBottom: CGFloat

    var body: some View {
        let origin = HoverCardPlacement.origin(
            for: blockFrame, opensToLeft: target.cardOpensToLeft,
            cardSize: CGSize(width: Self.width, height: target.estimatedCardHeight),
            columnWidth: columnSize.width, columnHeight: columnSize.height, minX: TimelineMetrics.labelWidth,
            visibleTop: visibleTop, visibleBottom: visibleBottom)
        content
            .padding(10)
            .frame(width: Self.width, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.12)))
            .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
            .offset(x: origin.x, y: origin.y)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @ViewBuilder private var content: some View {
        switch target {
        case .session(let block): SessionHoverCardContent(block: block)
        case .entry(let entry, let project, let range): EntryHoverCardContent(entry: entry, project: project, range: range)
        }
    }
}
