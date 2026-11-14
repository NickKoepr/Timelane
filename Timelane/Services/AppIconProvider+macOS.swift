#if os(macOS)
import AppKit
import SwiftUI

extension AppIconProvider {
    static func loadIcon(for bundleIdentifier: String) -> Image? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return nil }
        return Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
    }
}
#endif
