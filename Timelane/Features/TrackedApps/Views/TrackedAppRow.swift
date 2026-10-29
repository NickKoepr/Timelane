import SwiftUI

struct TrackedAppRow: View {
    let app: TrackedApp
    let projects: [Project]
    let onProjectChange: (Int64?) -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            AppIconView(bundleIdentifier: app.bundleIdentifier, size: 28)
                .fixedSize()
            VStack(alignment: .leading, spacing: 0) {
                Text(app.name).lineLimit(1).truncationMode(.tail)
                Text(app.bundleIdentifier)
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 8)
            Picker("Project", selection: Binding(get: { app.projectId }, set: onProjectChange)) {
                Text("No project").tag(Int64?.none)
                ForEach(projects) { project in Text(project.name).tag(project.id) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
            .help("Project that gets hours automatically while you use \(app.name)")
            Button(action: onRemove) { Image(systemName: "minus.circle") }
                .buttonStyle(.borderless)
                .fixedSize()
                .help("Stop tracking \(app.name)")
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let projects = [Project(id: 1, name: "Project A", colorHex: "#4F8EF7"), Project(id: 2, name: "Internal", colorHex: "#34C759")]
    return TrackedAppRow(app: TrackedApp(bundleIdentifier: "com.apple.dt.Xcode", name: "Xcode", projectId: 1),
                         projects: projects, onProjectChange: { _ in }, onRemove: {}).padding()
}
