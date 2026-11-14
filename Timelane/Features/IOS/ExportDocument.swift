#if os(iOS)
import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Wraps a finished export (`ExportFile`) so `fileExporter` can save it to Files, iCloud Drive, ….
struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    /// Every format of `ExportFormats` (plus plain data); the actual type is passed to `fileExporter`.
    static var writableContentTypes: [UTType] { [.data] + ExportFormats.all.map(\.contentType) }

    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        data = contents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
#endif
