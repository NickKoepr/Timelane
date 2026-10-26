import SwiftUI

/// Reports the pointer entering/leaving a block to the shared hover state, with the block's frame in the
/// "timeline" space. Apply it to the block *before* the vertical `.offset`; `y` and `height` come from the geometry.
private struct HoverReporting: ViewModifier {
    let target: HoverTarget
    let hover: TimelineHoverState
    let y: CGFloat
    let height: CGFloat
    @State private var horizontal: (x: CGFloat, width: CGFloat) = (0, 0)

    private var frame: CGRect { CGRect(x: horizontal.x, y: y, width: horizontal.width, height: height) }

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .named("timeline")) }, action: {
                horizontal = ($0.minX, $0.width)
                hover.update(target, frame: frame)
            })
            .onChange(of: y) { hover.update(target, frame: frame) }
            .onChange(of: height) { hover.update(target, frame: frame) }
            .onHover { inside in
                if inside { hover.enter(target, frame: frame) } else { hover.leave(target) }
            }
            .onDisappear { hover.leave(target) }
    }
}

extension View {
    func reportsHover(_ target: HoverTarget, to hover: TimelineHoverState, y: CGFloat, height: CGFloat) -> some View {
        modifier(HoverReporting(target: target, hover: hover, y: y, height: height))
    }
}
