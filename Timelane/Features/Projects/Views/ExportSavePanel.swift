import AppKit
import UniformTypeIdentifiers

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
