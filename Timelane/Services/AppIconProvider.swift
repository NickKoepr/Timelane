import SwiftUI

/// Looks up (and caches) application icons by bundle identifier.
/// Only the Mac knows the icons of other apps; on iOS every lookup is `nil`.
@MainActor
final class AppIconProvider {
    static let shared = AppIconProvider()
    private var cache: [String: Image] = [:]

    func icon(for bundleIdentifier: String) -> Image? {
        if let cached = cache[bundleIdentifier] { return cached }
        guard let icon = Self.loadIcon(for: bundleIdentifier) else { return nil }
        cache[bundleIdentifier] = icon
        return icon
    }
}
