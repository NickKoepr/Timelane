import CoreGraphics
import Foundation
import Testing
@testable import Timelane

@MainActor
struct MenuBarTimelineTests {
    @Test func zoomStateWithCustomKeyIsIndependent() {
        let defaults = UserDefaults(suiteName: "Zoom-\(UUID())")!
        TimelineZoomState(defaults: defaults).set(.quarterHour)
        let menuBar = TimelineZoomState(defaults: defaults, key: "menuBarTimelineZoomLevel", defaultLevel: .halfHour)
        #expect(menuBar.zoom == .halfHour)
        menuBar.set(.tenMinutes)
        #expect(TimelineZoomState(defaults: defaults).zoom == .quarterHour)
        #expect(TimelineZoomState(defaults: defaults, key: "menuBarTimelineZoomLevel").zoom == .tenMinutes)
    }

    @Test func searchWithoutCreationOffersNoNewProject() {
        var search = ProjectSearch(projects: [Project(id: 1, name: "Website", colorHex: "#000000")],
                                   highlightedId: 1, allowsCreating: false)
        search.query = "Nothing"
        #expect(search.newProjectName == nil)
        #expect(search.highlightedProject == nil)
    }

    @Test func confirmWithoutMatchDoesNothingWhenCreationIsNotAllowed() async throws {
        let db = try AppDatabase.inMemory()
        let repo = GRDBProjectRepository(database: db)
        let viewModel = TimeEntryFormViewModel(
            form: .new(range: DateRange(start: .now.addingTimeInterval(-3600), end: .now), projectId: nil),
            projects: [], projectRepository: repo,
            editor: TimeEntryEditor(repository: GRDBTimeEntryRepository(database: db)),
            allowsCreatingProjects: false, onFinish: { _ in })
        viewModel.search.query = "Brand New"
        await viewModel.confirmSearch()
        await viewModel.createProject()
        #expect(viewModel.form.projectId == nil)
        var iterator = repo.observeProjects(includeArchived: true).makeAsyncIterator()
        #expect(await iterator.next()?.isEmpty == true)
    }

    @Test func choosingAProjectMovesTheKeyboardHighlight() throws {
        let db = try AppDatabase.inMemory()
        let projects = [Project(id: 1, name: "Website", colorHex: "#000000"), Project(id: 2, name: "Admin", colorHex: "#000000")]
        let viewModel = TimeEntryFormViewModel(
            form: .new(range: DateRange(start: .now.addingTimeInterval(-3600), end: .now), projectId: 1),
            projects: projects, projectRepository: GRDBProjectRepository(database: db),
            editor: TimeEntryEditor(repository: GRDBTimeEntryRepository(database: db)),
            allowsCreatingProjects: true, onFinish: { _ in })
        #expect(viewModel.search.highlightedId == 1)
        viewModel.choose(projects[1])
        #expect(viewModel.form.projectId == 2 && viewModel.search.highlightedId == 2)
    }

    @Test func hoverCardStaysInsideANarrowColumn() {
        let card = CGSize(width: 220, height: 100)
        func origin(_ block: CGRect, left: Bool) -> CGPoint {
            HoverCardPlacement.origin(for: block, opensToLeft: left, cardSize: card, columnWidth: 360, columnHeight: 2000,
                                      minX: 54, visibleTop: 0, visibleBottom: 600)
        }
        let appLane = CGRect(x: 56, y: 100, width: 117, height: 40)
        let entryLane = CGRect(x: 181, y: 100, width: 176, height: 40)
        for p in [origin(appLane, left: false), origin(entryLane, left: true), origin(entryLane, left: false)] {
            #expect(p.x >= 54 && p.x + 220 <= 360)
        }
    }
}
