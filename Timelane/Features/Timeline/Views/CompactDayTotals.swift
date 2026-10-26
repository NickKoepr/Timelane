import SwiftUI

/// "3:15 / 5:40" — registered / tracked on one line, for narrow bars.
struct CompactDayTotals: View {
    let registered: TimeInterval
    let tracked: TimeInterval

    var body: some View {
        HStack(spacing: 4) {
            Text(DurationFormatter.hoursMinutes(registered)).fontWeight(.semibold)
            Text("/").foregroundStyle(.secondary)
            Text(DurationFormatter.hoursMinutes(tracked))
        }
        .font(.callout.monospacedDigit())
        .lineLimit(1)
        .fixedSize()
        .help("Registered / Tracked")
    }
}
