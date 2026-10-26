import SwiftUI

/// The 1 pt vertical line between the two lanes.
struct LaneDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
