import AppKit

/// Looks up (and caches) application icons by bundle identifier.
@MainActor
final class AppIconProvider {
    static let shared = AppIconProvider()
    private var cache: [String: NSImage] = [:]

    func icon(for bundleIdentifier: String) -> NSImage? {
        if let cached = cache[bundleIdentifier] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        cache[bundleIdentifier] = icon
        return icon
    }
}
