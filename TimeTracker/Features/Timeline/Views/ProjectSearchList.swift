import SwiftUI

/// Search field plus list of projects; the chosen project gets a checkmark.
struct ProjectSearchList: View {
    @Bindable var viewModel: TimeEntryFormViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Search or create project", text: $viewModel.search.query)
                .textFieldStyle(.roundedBorder)
                .onSubmit { Task { await viewModel.confirmSearch() } }
                .onKeyPress(.upArrow) { viewModel.search.moveHighlight(by: -1); return .handled }
                .onKeyPress(.downArrow) { viewModel.search.moveHighlight(by: 1); return .handled }
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(viewModel.search.filtered) { project in
                        row(color: project.color, title: project.name,
                            highlighted: project.id == viewModel.search.highlightedId,
                            chosen: project.id == viewModel.form.projectId)
                            .onTapGesture { viewModel.choose(project) }
                    }
                    if let name = viewModel.search.newProjectName {
                        row(symbol: "plus.circle", title: "New project “\(name)”",
                            highlighted: viewModel.search.filtered.isEmpty, chosen: false)
                            .onTapGesture { Task { await viewModel.createProject() } }
                    }
                    if viewModel.search.filtered.isEmpty && viewModel.search.newProjectName == nil {
                        Text("No projects yet. Type a name to create one.")
                            .font(.callout).foregroundStyle(.secondary).padding(6)
                    }
                }
            }
            .frame(height: 120)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private func row(color: Color? = nil, symbol: String? = nil, title: String,
                     highlighted: Bool, chosen: Bool) -> some View {
        HStack(spacing: 8) {
            if let color { Circle().fill(color).frame(width: 10, height: 10) }
            if let symbol { Image(systemName: symbol).foregroundStyle(.secondary) }
            Text(title).lineLimit(1)
            Spacer()
            if chosen { Image(systemName: "checkmark").foregroundStyle(Color.accentColor) }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(chosen ? Color.accentColor.opacity(0.2) : highlighted ? Color.primary.opacity(0.08) : .clear,
                    in: RoundedRectangle(cornerRadius: 5))
        .contentShape(Rectangle())
    }
}
