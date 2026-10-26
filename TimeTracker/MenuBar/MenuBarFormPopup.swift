import SwiftUI

/// The time entry form as a popup card over the dimmed panel. Drawn inside the panel's own window:
/// a real sheet is a separate window, which makes the MenuBarExtra panel lose focus and close,
/// and makes the (inactive) app bounce in the Dock to ask for attention.
struct MenuBarFormPopup: View {
    let viewModel: TimeEntryFormViewModel
    let onManageProjects: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            // Swallows clicks so the timeline underneath can't be used while the popup is open.
            Color.black.opacity(0.25)
                .contentShape(Rectangle())
                .onTapGesture {}
            ViewThatFits(in: .vertical) {
                form
                ScrollView { form }
            }
            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator))
            .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
            .padding(12)
        }
    }

    private var form: some View {
        TimeEntryFormContent(viewModel: viewModel, onManageProjects: onManageProjects)
            .padding(16)
    }
}
