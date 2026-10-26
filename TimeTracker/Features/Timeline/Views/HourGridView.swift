import SwiftUI

/// Time labels plus hour, label and minor lines behind the lanes; density follows the zoom level.
struct HourGridView: View {
    let geometry: TimelineGeometry
    var zoom: TimelineZoom = .hour

    var body: some View {
        let layout = HourGridLayout(geometry: geometry, zoom: zoom)
        ZStack(alignment: .topLeading) {
            Canvas { context, size in
                for line in layout.lines {
                    var path = Path()
                    path.move(to: CGPoint(x: TimelineMetrics.labelWidth, y: line.y))
                    path.addLine(to: CGPoint(x: size.width, y: line.y))
                    context.stroke(path, with: .color(.secondary.opacity(opacity(line.kind))),
                                   lineWidth: line.kind == .hour ? 1 : 0.5)
                }
            }
            ForEach(layout.labels, id: \.date) { label in
                Text(label.date.formatted(date: .omitted, time: .shortened))
                    .font((label.isHour ? Font.caption : Font.caption2).monospacedDigit())
                    .foregroundStyle(label.isHour ? .secondary : .tertiary)
                    .frame(width: TimelineMetrics.labelWidth - 8, alignment: .trailing)
                    .offset(y: label.y - 7)
            }
        }
        .frame(height: geometry.totalHeight)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func opacity(_ kind: HourGridLayout.LineKind) -> Double {
        switch kind {
        case .hour: 0.35
        case .label: 0.2
        case .minor: 0.1
        }
    }
}

#Preview {
    HourGridView(geometry: TimelineGeometry(day: .day(of: .now))).frame(width: 400)
}
