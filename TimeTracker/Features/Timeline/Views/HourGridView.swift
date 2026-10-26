import SwiftUI

/// Hour labels plus hour and quarter-hour lines behind the lanes.
struct HourGridView: View {
    let geometry: TimelineGeometry

    private var hourCount: Int { Int((geometry.day.duration / 3600).rounded(.up)) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, size in
                for quarter in 0...(hourCount * 4) {
                    let date = geometry.day.start.addingTimeInterval(Double(quarter) * 900)
                    let y = geometry.y(for: date)
                    let isHour = quarter % 4 == 0
                    var path = Path()
                    path.move(to: CGPoint(x: TimelineMetrics.labelWidth, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(.secondary.opacity(isHour ? 0.35 : 0.12)),
                                   lineWidth: isHour ? 1 : 0.5)
                }
            }
            ForEach(0..<hourCount, id: \.self) { hour in
                let date = geometry.day.start.addingTimeInterval(Double(hour) * 3600)
                Text(date.formatted(date: .omitted, time: .shortened))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: TimelineMetrics.labelWidth - 8, alignment: .trailing)
                    .offset(y: geometry.y(for: date) - 7)
            }
        }
        .frame(height: geometry.totalHeight)
        .accessibilityHidden(true)
    }
}

#Preview {
    HourGridView(geometry: TimelineGeometry(day: .day(of: .now))).frame(width: 400)
}
