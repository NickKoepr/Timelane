import Testing
@testable import Timelane

@MainActor
struct ProjectFormViewModelTests {
    @Test func rejectsEmptyAndReportsDuplicates() async throws {
        let repo = GRDBProjectRepository(database: try AppDatabase.inMemory())
        _ = try await repo.save(Project(name: "Alpha", colorHex: "#4F8EF7"))

        let form = ProjectFormViewModel(project: nil, defaultColorHex: "#34C759", repository: repo)
        form.name = "   "
        #expect(!form.canSave)
        #expect(await form.save() == false)

        form.name = " alpha "
        #expect(await form.save() == false)
        #expect(form.errorMessage == RepositoryError.duplicateName.errorDescription)

        form.name = "Beta"
        #expect(await form.save() == true)
    }

    @Test func editingKeepsIdentity() async throws {
        let repo = GRDBProjectRepository(database: try AppDatabase.inMemory())
        let saved = try await repo.save(Project(name: "Alpha", colorHex: "#4F8EF7"))
        let form = ProjectFormViewModel(project: saved, defaultColorHex: "#000000", repository: repo)
        form.name = "Alpha renamed"
        form.colorHex = "#FF9500"
        #expect(await form.save())
        let all = try await repo.monthTotals(in: .month(of: .now))
        #expect(all.count == 1)
        #expect(all[0].project.name == "Alpha renamed")
        #expect(all[0].project.colorHex == "#FF9500")
    }

    @Test func customIdRoundTripsAndNormalises() async throws {
        let repo = GRDBProjectRepository(database: try AppDatabase.inMemory())
        let form = ProjectFormViewModel(project: nil, defaultColorHex: "#34C759", repository: repo)
        form.name = "Alpha"
        form.customId = "  ACME-042  "
        #expect(await form.save())
        let saved = try await repo.projects(includeArchived: true)[0]
        #expect(saved.customId == "ACME-042")

        let edit = ProjectFormViewModel(project: saved, defaultColorHex: "#000000", repository: repo)
        #expect(edit.customId == "ACME-042")
        edit.customId = "   "
        #expect(await edit.save())
        #expect(try await repo.projects(includeArchived: true)[0].customId == nil)
    }

    @Test func tooLongCustomIdBlocksSaving() throws {
        let repo = GRDBProjectRepository(database: try AppDatabase.inMemory())
        let form = ProjectFormViewModel(project: nil, defaultColorHex: "#34C759", repository: repo)
        form.name = "Alpha"
        form.customId = String(repeating: "x", count: ProjectCustomId.maxLength)
        #expect(form.canSave)
        form.customId += "x"
        #expect(!form.canSave)
    }

    @Test func duplicateCustomIdSetsErrorMessage() async throws {
        let repo = GRDBProjectRepository(database: try AppDatabase.inMemory())
        _ = try await repo.save(Project(name: "Alpha", colorHex: "#4F8EF7", customId: "A-1"))
        let form = ProjectFormViewModel(project: nil, defaultColorHex: "#34C759", repository: repo)
        form.name = "Beta"
        form.customId = "a-1"
        #expect(await form.save() == false)
        #expect(form.errorMessage == RepositoryError.duplicateCustomId.errorDescription)
    }
}
