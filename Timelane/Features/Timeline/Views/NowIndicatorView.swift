import SwiftUI

/// Red line at the current time; only visible when the shown day contains "now".
struct NowIndicatorView: View {
    let geometry: TimelineGeometry

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            if geometry.day.contains(context.date) {
                HStack(spacing: 0) {
                    Circle().frame(width: 8, height: 8)
                    Rectangle().frame(height: 1.5)
                }
                .foregroundStyle(.red)
                .padding(.leading, TimelineMetrics.labelWidth - 4)
                .offset(y: geometry.y(for: context.date) - 4)
                .allowsHitTesting(false)
            }
        }
        .frame(height: geometry.totalHeight, alignment: .top)
        .allowsHitTesting(false)
    }
}
