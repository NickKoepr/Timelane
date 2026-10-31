import SwiftUI

/// The clock from the app icon as a vector, so it stays sharp at any size and takes the foreground style.
/// Geometry mirrors `drawClock` in `Tools/generate-app-icon.swift` (outer radius 280 on a 1024 canvas, hands at 10:10).
struct OnboardingClockMark: View {
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 560
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let style = GraphicsContext.Shading.style(.foreground)

            let ringWidth = 60 * scale
            let ringRadius = 280 * scale - ringWidth / 2
            let ring = Path(ellipseIn: CGRect(x: center.x - ringRadius, y: center.y - ringRadius,
                                              width: ringRadius * 2, height: ringRadius * 2))
            context.stroke(ring, with: style, lineWidth: ringWidth)

            // Angles as in the icon script (counter-clockwise from 3 o'clock); y points down here.
            func hand(angle: CGFloat, length: CGFloat, width: CGFloat) {
                var path = Path()
                path.move(to: center)
                path.addLine(to: CGPoint(x: center.x + cos(angle) * length * scale,
                                         y: center.y - sin(angle) * length * scale))
                context.stroke(path, with: style, style: StrokeStyle(lineWidth: width * scale, lineCap: .round))
            }
            hand(angle: .pi / 2 + .pi / 3, length: 125, width: 50)  // hour hand towards 10
            hand(angle: .pi / 2 - .pi / 3, length: 170, width: 44)  // minute hand towards 2
            let dot = 42 * scale
            context.fill(Path(ellipseIn: CGRect(x: center.x - dot, y: center.y - dot, width: dot * 2, height: dot * 2)),
                         with: style)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

#Preview {
    OnboardingClockMark().foregroundStyle(Color.accentColor).frame(width: 70, height: 70).padding()
}
