import Foundation
import Testing
@testable import Timelane

@MainActor
struct MonthExportViewModelTests {
    let cal = MonthExportFixtures.cal

    func suite() -> UserDefaults {
        let name = "MonthExportViewModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func make(_ defaults: UserDefaults) async throws -> MonthExportViewModel {
        let db = try AppDatabase.inMemory()
        let projects = GRDBProjectRepository(database: db)
        let entries = GRDBTimeEntryRepository(database: db)
        let project = try await projects.save(Project(name: "Alpha", colorHex: "#4F8EF7"))
        try await entries.save([TimeEntry(projectId: project.id!, start: MonthExportFixtures.date(2026, 10, 5, 9),
                                          end: MonthExportFixtures.date(2026, 10, 5, 11))], deleting: [])
        let service = MonthExportService(projects: projects, timeEntries: entries, calendar: cal)
        return MonthExportViewModel(service: service, defaults: defaults)
    }

    @Test func preparesFileInSelectedFormat() async throws {
        let viewModel = try await make(suite())
        #expect(viewModel.selectedFormatID == ExportFormats.all[0].id)
        let xlsx = try #require(await viewModel.prepareFile(for: MonthExportFixtures.october))
        #expect(xlsx.fileName == "Timelane 2026-10.xlsx")
        #expect(!(try ZipTestReader.read(xlsx.data)).isEmpty)

        viewModel.selectedFormatID = "json"
        let json = try #require(await viewModel.prepareFile(for: MonthExportFixtures.october))
        #expect(json.fileName == "Timelane 2026-10.json")
        let object = try #require(try JSONSerialization.jsonObject(with: json.data) as? [String: Any])
        #expect(object["totalHours"] as? Double == 2)
    }

    @Test func remembersFormatAndFallsBack() async throws {
        let defaults = suite()
        let first = try await make(defaults)
        first.selectedFormatID = "json"
        #expect(try await make(defaults).selectedFormatID == "json")
        defaults.set("nonsense", forKey: MonthExportViewModel.lastFormatKey)
        #expect(try await make(defaults).selectedFormatID == ExportFormats.all[0].id)
    }

    @Test func writesAndReportsErrors() async throws {
        let viewModel = try await make(suite())
        let file = try #require(await viewModel.prepareFile(for: MonthExportFixtures.october))
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent(file.fileName)
        viewModel.write(file, to: url)
        #expect(viewModel.errorMessage == nil)
        #expect(try Data(contentsOf: url) == file.data)

        viewModel.write(file, to: dir.appendingPathComponent("missing/sub/file.xlsx"))
        #expect(viewModel.errorMessage != nil)
    }
}
