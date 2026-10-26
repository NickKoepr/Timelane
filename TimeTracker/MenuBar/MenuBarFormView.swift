import SwiftUI

/// The time entry form shown inline in the panel (sheets and popovers are unreliable in a MenuBarExtra window).
struct MenuBarFormView: View {
    let viewModel: TimeEntryFormViewModel
    let onManageProjects: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { viewModel.cancel() } label: { Label("Back", systemImage: "chevron.left") }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            Divider()
            ScrollView {
                TimeEntryFormContent(viewModel: viewModel, onManageProjects: onManageProjects)
                    .padding(12)
            }
        }
        .background(.background)
    }
}
