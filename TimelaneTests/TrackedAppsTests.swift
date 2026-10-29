import Foundation
import Testing
@testable import Timelane

struct AppCandidatesTests {
    let app = { (id: String, name: String) in ForegroundApp(bundleIdentifier: id, name: name) }

    @Test func mergesDedupesExcludesAndSorts() {
        let result = AppCandidates.merge(
            running: [app("b", "Beta"), app("a", "alpha new"), app("self", "Timelane")],
            known: [app("a", "Alpha old"), app("c", "Charlie"), app("t", "Tracked")],
            tracked: ["t"], ownBundleId: "self")
        #expect(result.map(\.bundleIdentifier) == ["a", "b", "c"])
        #expect(result.first?.name == "alpha new")
    }
}

struct TrackedAppRepositoryTests {
    func make() throws -> (GRDBTrackedAppRepository, GRDBAppSessionRepository) {
        let db = try AppDatabase.inMemory()
        return (GRDBTrackedAppRepository(database: db), GRDBAppSessionRepository(database: db))
    }

    @Test func addIgnoresDuplicatesAndSortsByName() async throws {
        let (repo, _) = try make()
        try await repo.add([TrackedApp(bundleIdentifier: "z", name: "Zed"), TrackedApp(bundleIdentifier: "a", name: "alpha"),
                            TrackedApp(bundleIdentifier: "z", name: "Zed again")])
        try await repo.add([TrackedApp(bundleIdentifier: "a", name: "Alpha 2")])
        let apps = try await repo.trackedApps()
        #expect(apps.map(\.bundleIdentifier) == ["a", "z"])
        #expect(apps.map(\.name) == ["alpha", "Zed"])
        #expect(apps.allSatisfy { $0.id != nil })
    }

    @Test func setProjectLinksAndUnlinks() async throws {
        let db = try AppDatabase.inMemory()
        let repo = GRDBTrackedAppRepository(database: db)
        let project = try await GRDBProjectRepository(database: db).save(Project(name: "P", colorHex: "#FFFFFF"))
        try await repo.add([TrackedApp(bundleIdentifier: "a", name: "A")])
        let id = try #require(try await repo.trackedApps().first?.id)
        try await repo.setProject(project.id, forAppId: id)
        #expect(try await repo.trackedApps().first?.projectId == project.id)
        try await repo.setProject(nil, forAppId: id)
        #expect(try await repo.trackedApps().first?.projectId == nil)
    }

    @Test func removeAndObserve() async throws {
        let (repo, _) = try make()
        try await repo.add([TrackedApp(bundleIdentifier: "a", name: "A"), TrackedApp(bundleIdentifier: "b", name: "B")])
        let first = try #require(try await repo.trackedApps().first)
        var iterator = repo.observeTrackedApps().makeAsyncIterator()
        #expect(await iterator.next()?.count == 2)
        try await repo.remove(id: first.id!)
        #expect(await iterator.next()?.map(\.bundleIdentifier) == ["b"])
    }

    @Test func knownAppsAreDistinctWithLatestName() async throws {
        let (_, sessions) = try make()
        let d = { (h: Int) in TestCalendar.date(2026, 11, 3, h) }
        for (id, name, hour) in [("x", "Old X", 8), ("y", "banana", 9), ("x", "New X", 10)] {
            _ = try await sessions.start(AppSession(bundleIdentifier: id, appName: name, start: d(hour), end: d(hour + 1)))
        }
        let known = try await sessions.knownApps()
        #expect(known.map(\.bundleIdentifier) == ["y", "x"])
        #expect(known.map(\.name) == ["banana", "New X"])
    }
}

@MainActor
struct TrackedAppsTrackerTests {
    let app = { (id: String) in ForegroundApp(bundleIdentifier: id, name: id.capitalized) }

    @Test func untrackedAppCreatesNoSession() async throws {
        let f = try TrackerFixture(tracked: ["safari"])
        await f.tracker.start()
        #expect(try await f.stored().isEmpty)
        #expect(!f.tracker.isCurrentAppTracked)
        f.advance(minutes: 5)
        await f.tracker.handle(.appActivated(app("safari")))
        #expect(try await f.stored().map(\.bundleIdentifier) == ["safari"])
        #expect(f.tracker.isCurrentAppTracked)
        f.advance(minutes: 5)
        await f.tracker.handle(.appActivated(app("mail")))
        let sessions = try await f.stored()
        #expect(sessions.count == 1 && sessions[0].end == TestCalendar.date(2026, 11, 3, 9, 10))
        await f.tracker.stop()
    }

    @Test func emptyListTracksNothing() async throws {
        let f = try TrackerFixture(tracked: [])
        await f.tracker.start()
        await f.tracker.handle(.appActivated(app("safari")))
        #expect(try await f.stored().isEmpty)
        await f.tracker.stop()
    }

    /// The tracker also listens to the repository, so list changes are made there to avoid racing its initial emission.
    func waitUntil(_ condition: () async throws -> Bool) async rethrows {
        for _ in 0..<300 where try await !condition() { try? await Task.sleep(for: .milliseconds(10)) }
    }

    @Test func addingFrontmostAppStartsSessionAndRemovingClosesIt() async throws {
        let f = try TrackerFixture(tracked: [])
        await f.tracker.start()
        f.advance(minutes: 5)
        try await f.trackedApps.add([TrackedApp(bundleIdentifier: "xcode", name: "Xcode")])
        try await waitUntil { try await f.stored().count == 1 }
        let started = try await f.stored()
        #expect(started.count == 1 && started[0].end == nil && started[0].start == f.clock)

        f.advance(minutes: 20)
        let id = try #require(try await f.trackedApps.trackedApps().first?.id)
        try await f.trackedApps.remove(id: id)
        try await waitUntil { try await f.stored().first?.end != nil }
        let closed = try await f.stored()
        #expect(closed.count == 1 && closed[0].end == f.clock)
        await f.tracker.stop()
    }

    @Test func eventWithUnchangedListDoesNothing() async throws {
        let f = try TrackerFixture(tracked: ["xcode"])
        await f.tracker.start()
        await f.tracker.handle(.trackedAppsChanged(["xcode"]))
        #expect(try await f.stored().count == 1)
        await f.tracker.stop()
    }

    @Test func pausedTrackerOpensNothingWhenListChanges() async throws {
        let f = try TrackerFixture(tracked: [])
        await f.tracker.start()
        await f.tracker.handle(.paused(.locked))
        try await f.trackedApps.add([TrackedApp(bundleIdentifier: "xcode", name: "Xcode")])
        await waitUntil { f.tracker.trackedBundleIds == ["xcode"] }
        #expect(try await f.stored().isEmpty)
        await f.tracker.handle(.resumed(.locked))
        #expect(try await f.stored().map(\.bundleIdentifier) == ["xcode"])
        await f.tracker.stop()
    }
}

@MainActor
struct AddTrackedAppViewModelTests {
    @Test func loadsCandidatesSelectsAndAdds() async throws {
        let db = try AppDatabase.inMemory()
        let tracked = GRDBTrackedAppRepository(database: db)
        let sessions = GRDBAppSessionRepository(database: db)
        try await tracked.add([TrackedApp(bundleIdentifier: "done", name: "Done")])
        _ = try await sessions.start(AppSession(bundleIdentifier: "seen", appName: "Seen",
                                                start: TestCalendar.date(2026, 11, 3, 9), end: TestCalendar.date(2026, 11, 3, 10)))
        var finished = false
        let vm = AddTrackedAppViewModel(
            trackedApps: tracked, appSessions: sessions,
            runningApps: { [ForegroundApp(bundleIdentifier: "run", name: "Running"), ForegroundApp(bundleIdentifier: "done", name: "Done"),
                            ForegroundApp(bundleIdentifier: "me", name: "Timelane")] },
            ownBundleId: "me", onFinish: { finished = true })
        await vm.load()
        #expect(vm.candidates.map(\.bundleIdentifier) == ["run", "seen"])
        vm.searchText = "seen"
        #expect(vm.filtered.map(\.bundleIdentifier) == ["seen"])
        vm.include([ForegroundApp(bundleIdentifier: "disk", name: "From Disk")])
        #expect(vm.candidates.count == 3 && vm.canAdd)
        vm.toggle(ForegroundApp(bundleIdentifier: "seen", name: "Seen"))
        await vm.add()
        #expect(finished)
        #expect(try await tracked.trackedApps().map(\.bundleIdentifier).sorted() == ["disk", "done", "seen"])
    }
}

@MainActor
struct TrackedAppsViewModelTests {
    @Test func setProjectUpdatesRepositoryAndOptionsKeepLinkedArchivedProject() async throws {
        let db = try AppDatabase.inMemory()
        let tracked = GRDBTrackedAppRepository(database: db)
        let projects = GRDBProjectRepository(database: db)
        let active = try await projects.save(Project(name: "Active", colorHex: "#FFFFFF"))
        let archived = try await projects.save(Project(name: "Old", colorHex: "#FFFFFF"))
        try await projects.archive(id: archived.id!, archived: true)
        try await tracked.add([TrackedApp(bundleIdentifier: "a", name: "A")])

        let vm = TrackedAppsViewModel(repository: tracked, projects: projects)
        let task = Task { await vm.task() }
        for _ in 0..<300 where !(vm.isLoaded && vm.projects.count == 2) { try await Task.sleep(for: .milliseconds(10)) }
        let app = try #require(vm.apps.first)
        #expect(vm.options(for: app).map(\.name) == ["Active"])

        await vm.setProject(archived.id, for: app)
        for _ in 0..<300 where vm.apps.first?.projectId == nil { try await Task.sleep(for: .milliseconds(10)) }
        #expect(vm.apps.first?.projectId == archived.id)
        #expect(Set(vm.options(for: vm.apps[0]).map(\.name)) == ["Active", "Old"])
        #expect(active.id != nil)
        task.cancel()
    }
}
