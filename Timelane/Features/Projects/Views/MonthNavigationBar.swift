import SwiftUI

/// Month bar of the Projects screen. Wide: "‹ October 2026 › This month" (≈ 350 pt);
/// compact: "‹ Oct 2026 › [calendar]" (≈ 230 pt). "This month" never disappears.
struct MonthNavigationBar: View {
    let title: String
    let shortTitle: String
    let isCurrentMonth: Bool
    let previous: () -> Void
    let next: () -> Void
    let current: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            bar(title: title) { Button("This month", action: current).disabled(isCurrentMonth) }
            bar(title: shortTitle) {
                Button(action: current) { Image(systemName: "calendar") }
                    .disabled(isCurrentMonth)
                    .help("This month (⌘T)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            MonthNavigationShortcuts(isCurrentMonth: isCurrentMonth, previous: previous, next: next, current: current)
        }
    }

    private func bar<Current: View>(title: String, @ViewBuilder current: () -> Current) -> some View {
        HStack(spacing: 8) {
            Button(action: previous) { Image(systemName: "chevron.left") }.help("Previous month (⌘←)")
            Text(title).font(.title2.weight(.semibold)).lineLimit(1).frame(minWidth: 120)
            Button(action: next) { Image(systemName: "chevron.right") }.help("Next month (⌘→)")
            current()
        }
        .lineLimit(1)
        .fixedSize()
    }
}

#Preview("900") { barPreview(width: 900) }
#Preview("480") { barPreview(width: 480) }
#Preview("250") { barPreview(width: 250) }

private func barPreview(width: CGFloat) -> some View {
    MonthNavigationBar(title: "September 2026", shortTitle: "Sep 2026", isCurrentMonth: false,
                       previous: {}, next: {}, current: {})
        .frame(width: width)
}
