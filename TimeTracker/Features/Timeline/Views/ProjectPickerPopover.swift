import SwiftUI

struct ProjectPickerPopover: View {
    @State var viewModel: ProjectPickerViewModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(DateRange.summary(viewModel.range))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField("Search or create project", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .focused($searchFocused)
                .onSubmit { Task { await viewModel.confirm() } }
                .onKeyPress(.upArrow) { viewModel.moveHighlight(by: -1); return .handled }
                .onKeyPress(.downArrow) { viewModel.moveHighlight(by: 1); return .handled }
            projectList
            TextField("Note (optional)", text: $viewModel.note)
                .textFieldStyle(.roundedBorder)
                .onSubmit { Task { await viewModel.confirm() } }
            if let message = viewModel.errorMessage {
                Text(message).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(12)
        .frame(width: 280)
        .onAppear { searchFocused = true }
    }

    private var projectList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(viewModel.filtered) { project in
                    row(color: project.color, title: project.name, highlighted: project.id == viewModel.highlightedId)
                        .onTapGesture { Task { await viewModel.select(project) } }
                }
                if let name = viewModel.newProjectName {
                    row(symbol: "plus.circle", title: "New project “\(name)”", highlighted: viewModel.filtered.isEmpty)
                        .onTapGesture { Task { await viewModel.createAndSelect() } }
                }
                if viewModel.filtered.isEmpty && viewModel.newProjectName == nil {
                    Text("No projects yet. Type a name to create one.")
                        .font(.callout).foregroundStyle(.secondary).padding(6)
                }
            }
        }
        .frame(maxHeight: 220)
    }

    private func row(color: Color? = nil, symbol: String? = nil, title: String, highlighted: Bool) -> some View {
        HStack(spacing: 8) {
            if let color { Circle().fill(color).frame(width: 10, height: 10) }
            if let symbol { Image(systemName: symbol).foregroundStyle(.secondary) }
            Text(title).lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(highlighted ? Color.accentColor.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 5))
        .contentShape(Rectangle())
    }
}

private extension DateRange {
    /// "10:00 – 13:00 (3:00)"
    static func summary(_ range: DateRange) -> String { TimelineSelection(range: range).label }
}
