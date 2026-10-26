import Foundation
import Testing
@testable import TimeTracker

@MainActor
struct TimelineZoomTests {
    @Test func levelsRunFromHourToTenMinutes() {
        #expect(TimelineZoom.allCases.map(\.pointsPerHour) == [80, 160, 320, 480])
        #expect(TimelineZoom.tenMinutes.pointsPerHour / 6 == 80)
        #expect(TimelineZoom.allCases.map(\.labelIntervalMinutes) == [60, 30, 15, 10])
        #expect(TimelineZoom.allCases.map(\.minorLineMinutes) == [15, 15, 5, 5])
    }

    @Test func zoomingClampsAtTheEnds() {
        #expect(TimelineZoom.hour.zoomedOut() == .hour)
        #expect(TimelineZoom.hour.zoomedIn() == .halfHour)
        #expect(TimelineZoom.tenMinutes.zoomedIn() == .tenMinutes)
        #expect(TimelineZoom.tenMinutes.zoomedOut() == .quarterHour)
    }

    @Test func stateStepsAndReportsLimits() {
        let state = TimelineZoomState(defaults: UserDefaults(suiteName: "Zoom-\(UUID())")!)
        #expect(state.zoom == .hour && !state.canZoomOut && state.canZoomIn)
        state.zoomIn(); state.zoomIn(); state.zoomIn(); state.zoomIn()
        #expect(state.zoom == .tenMinutes && !state.canZoomIn && state.canZoomOut)
        state.zoomOut()
        #expect(state.zoom == .quarterHour)
    }

    @Test func stateRemembersLevel() {
        let defaults = UserDefaults(suiteName: "Zoom-\(UUID())")!
        TimelineZoomState(defaults: defaults).set(.quarterHour)
        #expect(TimelineZoomState(defaults: defaults).zoom == .quarterHour)
    }

    @Test func viewModelGeometryFollowsZoom() throws {
        let db = try AppDatabase.inMemory()
        let zoom = TimelineZoomState(defaults: UserDefaults(suiteName: "Zoom-\(UUID())")!)
        let repo = GRDBTimeEntryRepository(database: db)
        let vm = TimelineViewModel(timeEntries: repo, appSessions: GRDBAppSessionRepository(database: db),
                                   projects: GRDBProjectRepository(database: db), trackedApps: GRDBTrackedAppRepository(database: db),
                                   editor: TimeEntryEditor(repository: repo), zoomState: zoom)
        #expect(vm.geometry.pointsPerHour == 80)
        zoom.set(.tenMinutes)
        #expect(vm.geometry.pointsPerHour == 480)
    }
}
