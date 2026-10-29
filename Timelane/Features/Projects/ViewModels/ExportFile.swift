import Foundation
import UniformTypeIdentifiers

/// A finished export, ready to be written where the user chooses.
struct ExportFile: Sendable {
    var data: Data
    var fileName: String
    var contentType: UTType
}
