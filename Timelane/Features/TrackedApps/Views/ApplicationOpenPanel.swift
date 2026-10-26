import AppKit
import UniformTypeIdentifiers

/// "Choose from Applications…": lets the user pick .app bundles from disk.
enum ApplicationOpenPanel {
    @MainActor static func choose() -> [ForegroundApp] {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Choose"
        guard panel.runModal() == .OK else { return [] }
        return panel.urls.compactMap { url in
            guard let id = Bundle(url: url)?.bundleIdentifier else { return nil }
            return ForegroundApp(bundleIdentifier: id, name: FileManager.default.displayName(atPath: url.path)
                .replacingOccurrences(of: ".app", with: ""))
        }
    }
}
