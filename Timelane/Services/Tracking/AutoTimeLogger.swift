import Foundation

/// Turns "a linked app is in the foreground" into a time entry that grows live (see `AutoLogPlanner`).
/// Uses its own editor so automatic writes stay apart from the user's edits.
///
/// Links apply to new time only: the logger only ever changes the end of its own entry for the current run.
/// It never changes the project of an existing entry and never touches time recorded before the current run
/// (except continuing its own entry across a small gap of the same project). A link change ends the run
/// and starts a new one.
@MainActor
final class AutoTimeLogger {
    private(set) var errorMessage: String?

    private let repository: any TimeEntryRepository
    private let editor: TimeEntryEditor
    private let trackedApps: any TrackedAppRepository
    private let now: () -> Date

    private var projectByBundleId: [String: Int64] = [:]
    private var activeBundleId: String?
    private var run: AutoLogRun?
    private var entry: AutoLogEntry?

    init(timeEntries: any TimeEntryRepository, trackedApps: any TrackedAppRepository, now: @escaping () -> Date = { .now }) {
        self.repository = timeEntries
        self.editor = TimeEntryEditor(repository: timeEntries)
        self.trackedApps = trackedApps
        self.now = now
    }

    // MARK: Tracked app mapping

    /// Loads the app → project mapping once, so it is known before the first session starts.
    func load() async {
        do { projectByBundleId = Self.mapping(try await trackedApps.trackedApps()) } catch { errorMessage = error.localizedDescription }
    }

    /// Keeps the mapping current; a changed link of the active app ends its run and starts a new one.
    func observe() async {
        for await apps in trackedApps.observeTrackedApps() {
            projectByBundleId = Self.mapping(apps)
            guard let activeBundleId, projectByBundleId[activeBundleId] != run?.projectId else { continue }
            let at = now()
            await finish(at: at)
            run = projectByBundleId[activeBundleId].map { AutoLogRun(projectId: $0, start: at) }
        }
    }

    private static func mapping(_ apps: [TrackedApp]) -> [String: Int64] {
        Dictionary(apps.compactMap { app in app.projectId.map { (app.bundleIdentifier, $0) } }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: Called by the tracker

    func sessionStarted(bundleIdentifier: String, at: Date) async {
        await finish(at: at)
        activeBundleId = bundleIdentifier
        run = projectByBundleId[bundleIdentifier].map { AutoLogRun(projectId: $0, start: at) }
    }

    func sessionEnded(at: Date) async {
        await finish(at: at)
        activeBundleId = nil
    }

    /// Called every `TrackingSettings.autoLogInterval`: creates or extends the entry.
    func tick() async {
        guard run != nil else { return }
        await step(at: now(), isFinal: false)
    }

    // MARK: Writing

    private func finish(at: Date) async {
        guard run != nil else { return }
        await step(at: at, isFinal: true)
        run = nil
    }

    private func step(at: Date, isFinal: Bool) async {
        guard let current = run else { return }
        do {
            let stored = try await ownEntry(until: at)
            switch AutoLogPlanner.plan(run: current, entry: entry, entryIsIntact: stored != nil, now: at, isFinal: isFinal) {
            case .nothing:
                break
            case .create(let range):
                try await editor.create(projectId: current.projectId, range: range, note: nil)
                let created = try await repository.entries(in: range).first { $0.projectId == current.projectId && $0.start == range.start }
                entry = created?.id.map { AutoLogEntry(id: $0, projectId: current.projectId, start: range.start, lastEnd: range.end) }
            case .setEnd(let end):
                guard var stored, let own = entry else { break }
                stored.end = end
                try await editor.update(stored)
                entry = AutoLogEntry(id: own.id, projectId: own.projectId, start: own.start, lastEnd: end)
            case .delete:
                if let stored { try await editor.delete(stored) }
                entry = nil
            case .restart:
                entry = nil
                if !isFinal { run = AutoLogRun(projectId: current.projectId, start: at) }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// The logger's entry as stored now, or nil when the user changed it (deleted, moved, other project)
    /// or another entry sits in the way of growing it.
    private func ownEntry(until at: Date) async throws -> TimeEntry? {
        guard let own = entry else { return nil }
        let window = DateRange(start: own.lastEnd.addingTimeInterval(-1), end: max(at, own.lastEnd).addingTimeInterval(1))
        let stored = try await repository.entries(in: window)
        guard let mine = stored.first(where: { $0.id == own.id }),
              mine.projectId == own.projectId, mine.start == own.start, mine.end == own.lastEnd else { return nil }
        let blocked = stored.contains { $0.id != own.id && $0.start < at && $0.end > own.lastEnd }
        return blocked ? nil : mine
    }
}
