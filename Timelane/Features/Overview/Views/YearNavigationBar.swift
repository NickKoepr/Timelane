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
        Group {
            #if os(iOS)
            // A phone is always too narrow for the text button, and the menu picker under-reports its width to
            // `ViewThatFits` (which then picked the wide bar and truncated "This year").
            compactBar
            #else
            ViewThatFits(in: .horizontal) {
                bar { Button("This year", action: current).disabled(isCurrentYear) }
                compactBar
            }
            #endif
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            YearNavigationShortcuts(isCurrentYear: isCurrentYear, previous: previous, next: next, current: current)
        }
    }

    private var compactBar: some View {
        bar {
            Button(action: current) { Image(systemName: "calendar") }
                .disabled(isCurrentYear)
                .help("This year (⌘T)")
                .accessibilityLabel("This year")
        }
    }

    private func bar<Current: View>(@ViewBuilder current: () -> Current) -> some View {
        HStack(spacing: 8) {
            Button(action: previous) { Image(systemName: "chevron.left") }.help("Previous year (⌘←)")
            Text(title).font(.title2.weight(.semibold)).lineLimit(1).frame(minWidth: 60)
            Button(action: next) { Image(systemName: "chevron.right") }.help("Next year (⌘→)")
            current()
            Spacer(minLength: 8)
            projectFilter
                .frame(maxWidth: 180, alignment: .trailing) // a long name truncates; a short one hugs the trailing edge
                .layoutPriority(1)    // the filter gets its width first; on iOS a squeezed menu label wrapped onto two lines
        }
        .lineLimit(1)
    }

    @ViewBuilder private var projectFilter: some View {
        #if os(iOS)
        // A menu with a plain label: the menu-style Picker's button has an inner margin, so it never lined up with
        // the trailing edge of the content below.
        Menu { projectPicker } label: {
            HStack(spacing: 4) {
                Text(selectedProjectTitle).truncationMode(.tail)
                Image(systemName: "chevron.up.chevron.down").imageScale(.small)
            }
        }
        .accessibilityLabel("Project")
        .accessibilityValue(selectedProjectTitle)
        #else
        projectPicker.pickerStyle(.menu).labelsHidden()
        #endif
    }

    private var projectPicker: some View {
        Picker("Project", selection: $selectedProjectId) {
            Text("All projects").tag(Int64?.none)
            Divider()
            ForEach(projects) { project in
                Text(title(of: project)).tag(project.id)
            }
        }
    }

    private var selectedProjectTitle: String {
        projects.first { $0.id == selectedProjectId }.map(title(of:)) ?? "All projects"
    }

    private func title(of project: Project) -> String {
        project.isArchived ? "\(project.shortTitleWithCustomId) (archived)" : project.shortTitleWithCustomId
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
