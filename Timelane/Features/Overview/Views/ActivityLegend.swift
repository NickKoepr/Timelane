import SwiftUI

/// "Less ▢▢▢▢▢ More" under the heatmap.
struct ActivityLegend: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("Less")
            ForEach(ActivityLevel.allCases, id: \.self) { level in
                RoundedRectangle(cornerRadius: 2).fill(level.color).frame(width: 11, height: 11)
            }
            Text("More")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }
}

#Preview {
    ActivityLegend().padding()
}
