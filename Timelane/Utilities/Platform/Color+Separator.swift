import SwiftUI
#if os(iOS)
import UIKit
#endif

extension Color {
    /// The system's thin divider colour.
    static var platformSeparator: Color {
        #if os(macOS)
        Color(nsColor: .separatorColor)
        #else
        Color(uiColor: .separator)
        #endif
    }
}
