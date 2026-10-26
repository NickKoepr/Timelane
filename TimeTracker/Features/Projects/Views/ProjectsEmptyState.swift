import SwiftUI

/// Empty state of the Projects screen: no projects at all, or none to show this month.
struct ProjectsEmptyState: View {
    let hasAnyProjects: Bool
    let monthTitle: String
    let newProject: () -> Void

    var body: some View {
        Group {
            if hasAnyProjects {
                ContentUnavailableView("No hours in \(monthTitle)", systemImage: "clock",
                                       description: Text("Hours you register on the timeline show up here."))
            } else {
                ContentUnavailableView {
                    Label("No projects yet", systemImage: "folder.badge.plus")
                } description: {
                    Text("Create a project to start registering hours.")
                } actions: {
                    Button("New Project", action: newProject)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("No projects") {
    ProjectsEmptyState(hasAnyProjects: false, monthTitle: "October 2026", newProject: {})
        .frame(width: 600, height: 400)
}

#Preview("Nothing this month") {
    ProjectsEmptyState(hasAnyProjects: true, monthTitle: "October 2026", newProject: {})
        .frame(width: 600, height: 400)
}
