import Foundation

@MainActor @Observable
final class MonthExportViewModel {
    static let lastFormatKey = "export.lastFormatID"

    let formats: [any MonthExportFormat]
    var selectedFormatID: String {
        didSet { defaults.set(selectedFormatID, forKey: Self.lastFormatKey) }
    }
    var isChoosingFormat = false
    var errorMessage: String?
    private(set) var isExporting = false

    private let service: MonthExportService
    private let defaults: UserDefaults

    init(service: MonthExportService, formats: [any MonthExportFormat] = ExportFormats.all,
         defaults: UserDefaults = .standard) {
        self.service = service
        self.formats = formats
        self.defaults = defaults
        let stored = defaults.string(forKey: Self.lastFormatKey)
        selectedFormatID = formats.first { $0.id == stored }?.id ?? formats.first?.id ?? ""
    }

    var selectedFormat: (any MonthExportFormat)? { formats.first { $0.id == selectedFormatID } }

    func beginExport() { isChoosingFormat = true }

    /// Builds the file for `month` in the selected format. Returns nil (and sets `errorMessage`) on failure.
    func prepareFile(for month: DateRange) async -> ExportFile? {
        guard let format = selectedFormat, !isExporting else { return nil }
        isExporting = true
        defer { isExporting = false }
        do {
            let export = try await service.makeExport(for: month)
            let data = try format.data(for: export)
            let name = MonthExportFileName.make(for: month, fileExtension: format.fileExtension,
                                                calendar: service.calendar)
            return ExportFile(data: data, fileName: name, contentType: format.contentType)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func write(_ file: ExportFile, to url: URL) {
        do { try file.data.write(to: url, options: .atomic) } catch { errorMessage = error.localizedDescription }
    }
}
