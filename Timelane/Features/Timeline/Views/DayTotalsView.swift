import SwiftUI

struct DayTotalsView: View {
    let registered: TimeInterval
    let tracked: TimeInterval

    var body: some View {
        Grid(alignment: .trailing, horizontalSpacing: 10, verticalSpacing: 2) {
            GridRow {
                Text("Registered").foregroundStyle(.secondary)
                Text(DurationFormatter.hoursMinutes(registered)).fontWeight(.semibold)
            }
            GridRow {
                Text("Tracked").foregroundStyle(.secondary)
                Text(DurationFormatter.hoursMinutes(tracked))
            }
        }
        .font(.callout.monospacedDigit())
    }
}

#Preview {
    DayTotalsView(registered: 6 * 3600 + 15 * 60, tracked: 7 * 3600 + 40 * 60).padding()
}
