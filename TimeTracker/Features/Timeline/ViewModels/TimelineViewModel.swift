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
    private(set) var picker: ProjectPickerViewModel?

    private var sessions: [AppSession] = []
    private let timeEntries: any TimeEntryRepository
    private let appSessions: any AppSessionRepository
    private let projectRepository: any ProjectRepository
    let entryEditing: EntryEditingViewModel
    private let editor: TimeEntryEditor
    private let lastProject: LastProjectStore
    private let calendar: Calendar
    private let clock: () -> Date

    init(timeEntries: any TimeEntryRepository, appSessions: any AppSessionRepository,
         projects: any ProjectRepository, editor: TimeEntryEditor, lastProject: LastProjectStore = LastProjectStore(),
         calendar: Calendar = .current, clock: @escaping () -> Date = { .now }) {
        self.timeEntries = timeEntries
        self.appSessions = appSessions
        self.projectRepository = projects
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

    /// Drag released: open the project picker, or discard a too-small selection.
    func finishSelection() {
        guard let selection, selection.duration >= Self.minimumSelection else {
            cancelRegistration()
            return
        }
        openPicker(for: selection.range)
    }

    /// Click on an app session: assign the whole session to a project.
    func assign(_ block: AppSessionBlockModel) {
        selection = TimelineSelection(range: block.range)
        openPicker(for: block.range)
    }

    func cancelRegistration() {
        picker = nil
        selection = nil
    }

    private func openPicker(for range: DateRange) {
        picker = ProjectPickerViewModel(
            range: range, projects: projects, lastProjectId: lastProject.projectId,
            projectRepository: projectRepository, editor: editor,
            onFinish: { [weak self] projectId in
                if let projectId { self?.lastProject.projectId = projectId }
                self?.cancelRegistration()
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

    func select(_ entry: TimeEntry) { entryEditing.select(entry, projects: projects) }

    func deleteSelectedEntry() {
        guard let id = entryEditing.selectedEntryId, let entry = entries.first(where: { $0.id == id }) else { return }
        Task { await entryEditing.delete(entry) }
    }

    // MARK: Observation

    /// Observes the current day. Restart (via `.task(id: day)`) when the day changes.
    func task() async {
        let range = day
        now = clock()
        sessions = []
        entries = []
        rebuildBlocks()
        async let observedEntries: Void = observeEntries(in: range)
        async let observedSessions: Void = observeSessions(in: range)
        async let observedProjects: Void = observeProjects()
        async let ticking: Void = tick()
        _ = await (observedEntries, observedSessions, observedProjects, ticking)
    }

    private func observeEntries(in range: DateRange) async {
        for await value in timeEntries.observeEntries(in: range) { entries = value }
    }

    private func observeSessions(in range: DateRange) async {
        for await value in appSessions.observeSessions(in: range) {
            sessions = value
            now = clock()
            rebuildBlocks()
        }
    }

    private func observeProjects() async {
        for await value in projectRepository.observeProjects(includeArchived: true) { projects = value }
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
