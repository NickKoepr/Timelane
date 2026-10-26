import SwiftUI

extension View {
    /// Opaque instead of the panel's translucent material (`.background` resolves to it inside a
    /// `MenuBarExtra` window), so content underneath never shows through.
    func panelBackground() -> some View {
        background(Color(nsColor: .windowBackgroundColor))
    }
}
