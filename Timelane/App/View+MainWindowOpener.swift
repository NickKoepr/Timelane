import SwiftUI

extension View {
    /// Hands SwiftUI's `openWindow` to `environment`, so code outside views (a click on a reminder notification)
    /// can open the main window, also after it was closed.
    func registersMainWindowOpener(in environment: AppEnvironment) -> some View {
        modifier(MainWindowOpenerRegistration(environment: environment))
    }
}

private struct MainWindowOpenerRegistration: ViewModifier {
    let environment: AppEnvironment
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.onAppear {
            // Captured now: reading the environment later, outside a view update, gives no valid action.
            environment.openMainWindow = { [openWindow] in openWindow(id: "main") }
        }
    }
}
