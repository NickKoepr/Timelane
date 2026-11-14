#if os(iOS)
import SwiftUI

extension AppIconProvider {
    static func loadIcon(for bundleIdentifier: String) -> Image? { nil }
}
#endif
