import SwiftUI

/// Year bar of the Overview screen with the project filter on the trailing side.
/// Wide: "‹ 2026 › This year"; compact: "‹ 2026 › [calendar]". "This year" never disappears.
struct YearNavigationBar: View {
    let title: String
    let isCurrentYear: Bool
    let projects: [Project]
    @Binding var selectedProjectId: Int64?
    let previous: () -> Void
    let next: () -> Void
    let current: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            bar { Button("This year", action: current).disabled(isCurrentYear) }
            bar {
                Button(action: current) { Image(systemName: "calendar") }
                    .disabled(isCurrentYear)
                    .help("This year (⌘T)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            YearNavigationShortcuts(isCurrentYear: isCurrentYear, previous: previous, next: next, current: current)
        }
    }

    private func bar<Current: View>(@ViewBuilder current: () -> Current) -> some View {
        HStack(spacing: 8) {
            Button(action: previous) { Image(systemName: "chevron.left") }.help("Previous year (⌘←)")
            Text(title).font(.title2.weight(.semibold)).lineLimit(1).frame(minWidth: 60)
            Button(action: next) { Image(systemName: "chevron.right") }.help("Next year (⌘→)")
            current()
            Spacer(minLength: 8)
            Picker("Project", selection: $selectedProjectId) {
                Text("All projects").tag(Int64?.none)
                Divider()
                ForEach(projects) { project in
                    Text(project.isArchived ? "\(project.name) (archived)" : project.name).tag(project.id)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
        }
        .lineLimit(1)
    }
}

#Preview("900") { barPreview(width: 900) }
#Preview("480") { barPreview(width: 480) }

@MainActor private func barPreview(width: CGFloat) -> some View {
    @Previewable @State var selection: Int64?
    return YearNavigationBar(title: "2026", isCurrentYear: false,
                             projects: [Project(id: 1, name: "Alpha", colorHex: "#4F8EF7")],
                             selectedProjectId: $selection, previous: {}, next: {}, current: {})
        .frame(width: width)
}
