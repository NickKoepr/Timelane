import UniformTypeIdentifiers

#if os(macOS)
import AppKit

/// Asks where to save an export.
enum ExportSavePanel {
    @MainActor static func chooseURL(fileName: String, contentType: UTType) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [contentType]
        panel.nameFieldStringValue = fileName
        panel.canCreateDirectories = true
        panel.prompt = "Export"
        return panel.runModal() == .OK ? panel.url : nil
    }
}
#else
/// iOS has no save panel; exporting there goes through `fileExporter` / `ShareLink` in the iOS Projects screen.
/// Until that exists this reports "cancelled", so the shared Projects screen still compiles.
enum ExportSavePanel {
    @MainActor static func chooseURL(fileName: String, contentType: UTType) -> URL? { nil }
}
#endif
