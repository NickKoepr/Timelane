import CoreGraphics
import Foundation

@MainActor @Observable
final class TimelineViewModel {
    private(set) var day: DateRange
    private(set) var sessionBlocks: [AppSessionBlockModel] = []
    private(set) var entries: [TimeEntry] = []
    private(set) var projects: [Project] = []
    private(set) var now: Date
    private(set) var selection: TimelineSelection?
    /// The open time entry window (new or edit); presented as a sheet.
    private(set) var form: TimeEntryFormViewModel?

    /// nil until the tracked apps list has been loaded.
    private(set) var trackedApps: [TrackedApp]?

    private var allSessions: [AppSession] = []
    private var sessions: [AppSession] {
        let ids = Set((trackedApps ?? []).map(\.bundleIdentifier))
        return allSessions.filter { ids.contains($0.bundleIdentifier) }
    }
    private let timeEntries: any TimeEntryRepository
    private let appSessions: any AppSessionRepository
    private let projectRepository: any ProjectRepository
    private let trackedAppRepository: any TrackedAppRepository
    let entryEditing: EntryEditingViewModel
    private let editor: TimeEntryEditor
    private let lastProject: LastProjectStore
    private let calendar: Calendar
    private let clock: () -> Date

    init(timeEntries: any TimeEntryRepository, appSessions: any AppSessionRepository,
         projects: any ProjectRepository, trackedApps: any TrackedAppRepository, editor: TimeEntryEditor, lastProject: LastProjectStore = LastProjectStore(),
         calendar: Calendar = .current, clock: @escaping () -> Date = { .now }) {
        self.timeEntries = timeEntries
        self.appSessions = appSessions
        self.projectRepository = projects
        self.trackedAppRepository = trackedApps
        self.editor = editor
        self.entryEditing = EntryEditingViewModel(editor: editor)
        self.lastProject = lastProject
        self.calendar = calendar
        self.clock = clock
        self.now = clock()
        self.day = .day(of: clock(), calendar: calendar)
    }

    // MARK: Presentation

    var geometry: TimelineGeometry { TimelineGeometry(day: day) }
    var isToday: Bool { day.contains(clock()) }
    var title: String { day.start.formatted(.dateTime.weekday(.wide).day().month(.wide).year()) }
    var registeredTotal: TimeInterval { DayTotals.registered(entries: entries, in: day) }
    var trackedTotal: TimeInterval { DayTotals.tracked(sessions: sessions, in: day, now: now) }
    /// True once the list is loaded and still empty: the timeline shows a hint instead of sessions.
    var hasNoTrackedApps: Bool { trackedApps?.isEmpty == true }
    var hasActivity: Bool { !sessionBlocks.isEmpty || !entries.isEmpty }

    func project(id: Int64) -> Project? { projects.first { $0.id == id } }

    /// Where the timeline should be scrolled to when a day opens.
    var initialScrollDate: Date {
        isToday ? max(clock().addingTimeInterval(-3600), day.start) : day.start.addingTimeInterval(8 * 3600)
    }

    // MARK: Registering time

    static let minimumSelection: TimeInterval = 5 * 60

    /// Called continuously while dragging over the entry lane.
    func updateSelection(startY: CGFloat, currentY: CGFloat) {
        let geometry = geometry
        selection = TimelineSelection(anchor: geometry.snapped(geometry.date(forY: startY)),
                                      current: geometry.snapped(geometry.date(forY: currentY)))
    }

    /// Drag released: open the time entry window, or discard a too-small selection.
    func finishSelection() {
        guard let selection, selection.duration >= Self.minimumSelection else {
            cancelRegistration()
            return
        }
        openForm(.new(range: selection.range, projectId: defaultProjectId))
    }

    /// Click on an app session: open the window with the whole session's range.
    func assign(_ block: AppSessionBlockModel) {
        selection = TimelineSelection(range: block.range)
        openForm(.new(range: block.range, projectId: defaultProjectId))
    }

    /// Closes the window and clears the selection overlay.
    func cancelRegistration() {
        form = nil
        selection = nil
    }

    /// Last used project if it can still be chosen, else the first one.
    private var defaultProjectId: Int64? {
        let open = projects.filter { !$0.isArchived }
        return open.first { $0.id == lastProject.projectId }?.id ?? open.first?.id
    }

    private func openForm(_ values: TimeEntryForm) {
        form = TimeEntryFormViewModel(
            form: values, projects: projects, projectRepository: projectRepository, editor: editor,
            onFinish: { [weak self] projectId in
                guard let self else { return }
                if let projectId { lastProject.projectId = projectId }
                entryEditing.deselect()
                cancelRegistration()
            })
    }

    // MARK: Navigation

    func goToPreviousDay() { show(day.shiftedDays(-1, calendar: calendar)) }
    func goToNextDay() { show(day.shiftedDays(1, calendar: calendar)) }
    func goToToday() { show(.day(of: clock(), calendar: calendar)) }
    func go(to date: Date) { show(.day(of: date, calendar: calendar)) }

    private func show(_ range: DateRange) {
        cancelRegistration()
        entryEditing.reset()
        day = range
    }

    // MARK: Entries

    /// Click on an entry: select it and open the window in edit mode.
    func select(_ entry: TimeEntry) {
        selection = nil
        entryEditing.select(entry)
        openForm(.editing(entry))
    }

    func deleteSelectedEntry() {
        guard let id = entryEditing.selectedEntryId, let entry = entries.first(where: { $0.id == id }) else { return }
        Task { await entryEditing.delete(entry) }
    }

    // MARK: Observation

    /// Observes the current day. Restart (via `.task(id: day)`) when the day changes.
    func task() async {
        let range = day
        now = clock()
        allSessions = []
        entries = []
        rebuildBlocks()
        async let observedEntries: Void = observeEntries(in: range)
        async let observedSessions: Void = observeSessions(in: range)
        async let observedProjects: Void = observeProjects()
        async let observedApps: Void = observeTrackedApps()
        async let ticking: Void = tick()
        _ = await (observedEntries, observedSessions, observedProjects, observedApps, ticking)
    }

    private func observeEntries(in range: DateRange) async {
        for await value in timeEntries.observeEntries(in: range) { entries = value }
    }

    private func observeSessions(in range: DateRange) async {
        for await value in appSessions.observeSessions(in: range) {
            allSessions = value
            now = clock()
            rebuildBlocks()
        }
    }

    private func observeProjects() async {
        for await value in projectRepository.observeProjects(includeArchived: true) { projects = value }
    }

    private func observeTrackedApps() async {
        for await value in trackedAppRepository.observeTrackedApps() {
            trackedApps = value
            rebuildBlocks()
        }
    }

    /// The open session grows while viewing today.
    private func tick() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            now = clock()
            rebuildBlocks()
        }
    }

    private func rebuildBlocks() {
        sessionBlocks = AppSessionMerger.blocks(from: sessions, in: day, now: now)
    }
}
