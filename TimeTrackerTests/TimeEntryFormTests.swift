import Foundation
import Testing
@testable import TimeTracker

struct TimeEntryFormTests {
    func d(_ h: Int, _ m: Int = 0) -> Date { TestCalendar.date(2026, 11, 3, h, m) }

    @Test func validation() {
        var form = TimeEntryForm.new(range: DateRange(start: d(9), end: d(10)), projectId: 1)
        #expect(form.canSave && form.timeError == nil)
        form.end = d(9)
        #expect(form.timeError != nil && !form.canSave)
        form.end = d(9).addingTimeInterval(30)
        #expect(form.timeError != nil)
        form.end = d(10)
        form.projectId = nil
        #expect(!form.canSave)
    }

    @Test func makeEntryNormalizesTexts() throws {
        var form = TimeEntryForm.new(range: DateRange(start: d(9), end: d(10)), projectId: 1)
        form.title = "  Plan  "
        form.note = "   "
        let entry = try #require(form.makeEntry())
        #expect(entry.title == "Plan" && entry.note == nil)
    }

    @Test func editKeepsIdentityAndCreationDate() throws {
        let original = TimeEntry(id: 7, projectId: 1, start: d(9), end: d(10), title: "Old", createdAt: d(8), updatedAt: d(8))
        var form = TimeEntryForm.editing(original)
        #expect(form.title == "Old" && form.isEditing)
        form.title = ""
        form.end = d(11)
        let entry = try #require(form.makeEntry())
        #expect(entry.id == 7 && entry.createdAt == d(8) && entry.title == nil && entry.end == d(11))
    }
}

struct ProjectSearchTests {
    let projects = [Project(id: 1, name: "Website", colorHex: "#000000"), Project(id: 2, name: "Admin", colorHex: "#000000")]

    @Test func filtersAndHighlightsFirstMatch() {
        var search = ProjectSearch(projects: projects, highlightedId: 1)
        search.query = "adm"
        #expect(search.filtered.map(\.name) == ["Admin"])
        #expect(search.highlightedId == 2)
        #expect(search.newProjectName == "adm")
    }

    @Test func existingNameOffersNoCreation() {
        var search = ProjectSearch(projects: projects, highlightedId: 1)
        search.query = " website "
        #expect(search.newProjectName == nil)
    }

    @Test func highlightMovesAndClamps() {
        var search = ProjectSearch(projects: projects, highlightedId: 1)
        search.moveHighlight(by: 1)
        #expect(search.highlightedId == 2)
        search.moveHighlight(by: 1)
        #expect(search.highlightedId == 2)
        search.moveHighlight(by: -5)
        #expect(search.highlightedId == 1)
    }
}
