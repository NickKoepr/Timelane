import AppKit

/// Turns `ActivityEvent`s into stored `AppSession`s. All sources feed one serial event stream.
@MainActor @Observable
final class AppActivityTracker {
    private(set) var currentApp: ForegroundApp?
    private(set) var pauseReasons: Set<PauseReason> = []
    private(set) var errorMessage: String?
    private(set) var trackedBundleIds: Set<String> = []

    var isPaused: Bool { !pauseReasons.isEmpty }
    /// False while the frontmost app is not on the tracked list (or nothing is frontmost).
    var isCurrentAppTracked: Bool { currentApp.map { trackedBundleIds.contains($0.bundleIdentifier) } ?? false }

    private let repository: any AppSessionRepository
    private let trackedApps: any TrackedAppRepository
    private let heartbeat: any HeartbeatStore
    private let now: () -> Date
    private let frontmostProvider: () -> ForegroundApp?

    private var openSession: AppSession?
    private var continuation: AsyncStream<ActivityEvent>.Continuation?
    private var tasks: [Task<Void, Never>] = []
    private var systemObserver: SystemEventObserver?
    private var idleMonitor: IdleMonitor?

    init(repository: any AppSessionRepository, trackedApps: any TrackedAppRepository,
         heartbeat: any HeartbeatStore = UserDefaultsHeartbeat(),
         now: @escaping () -> Date = { .now },
         frontmostProvider: @escaping () -> ForegroundApp? = {
             NSWorkspace.shared.frontmostApplication.flatMap(ForegroundApp.init)
         }) {
        self.repository = repository
        self.trackedApps = trackedApps
        self.heartbeat = heartbeat
        self.now = now
        self.frontmostProvider = frontmostProvider
    }

    // MARK: Lifecycle

    /// Closes leftovers from a crash, starts the first session and begins listening to the system.
    func start() async {
        guard continuation == nil else { return }
        await perform { try await repository.closeDanglingSessions(at: heartbeat.lastBeat) }
        await perform { trackedBundleIds = Set(try await trackedApps.trackedApps().map(\.bundleIdentifier)) }
        currentApp = frontmostProvider()
        await switchSession(to: currentApp)
        beat()

        let (stream, continuation) = AsyncStream<ActivityEvent>.makeStream()
        self.continuation = continuation
        systemObserver = SystemEventObserver(sink: { continuation.yield($0) })
        let idle = IdleMonitor(sink: { continuation.yield($0) })
        idle.start()
        idleMonitor = idle
        tasks = [
            Task { for await event in stream { await self.handle(event) } },
            Task { await self.runHeartbeat() },
            Task { await self.observeTrackedApps(into: continuation) },
        ]
    }

    /// Closes the open session; call when the app terminates.
    func stop() async {
        tasks.forEach { $0.cancel() }
        tasks = []
        systemObserver?.stop()
        idleMonitor?.stop()
        continuation?.finish()
        continuation = nil
        await closeSession(at: now())
        beat()
    }

    // MARK: Events

    func handle(_ event: ActivityEvent) async {
        switch event {
        case .appActivated(let app):
            currentApp = app
            if !isPaused { await switchSession(to: app) }
        case .paused(let reason, let at):
            pauseReasons.insert(reason)
            await closeSession(at: at ?? now())
        case .resumed(let reason):
            pauseReasons.remove(reason)
            guard !isPaused else { return }
            currentApp = frontmostProvider() ?? currentApp
            await switchSession(to: currentApp)
        case .trackedAppsChanged(let ids):
            guard ids != trackedBundleIds else { return }
            trackedBundleIds = ids
            if !isPaused { await switchSession(to: currentApp) }
        }
    }

    /// Feeds list changes into the event stream so all state changes stay serial.
    private func observeTrackedApps(into continuation: AsyncStream<ActivityEvent>.Continuation) async {
        for await apps in trackedApps.observeTrackedApps() {
            continuation.yield(.trackedAppsChanged(Set(apps.map(\.bundleIdentifier))))
        }
    }

    // MARK: Sessions

    /// Opens a session for `app` when it is tracked; otherwise only closes the open one.
    private func switchSession(to candidate: ForegroundApp?) async {
        let app = candidate.flatMap { trackedBundleIds.contains($0.bundleIdentifier) ? $0 : nil }
        if let app, openSession?.bundleIdentifier == app.bundleIdentifier { return }
        await closeSession(at: now())
        guard let app else { return }
        let session = AppSession(bundleIdentifier: app.bundleIdentifier, appName: app.name, start: now())
        await perform { openSession = try await repository.start(session) }
    }

    private func closeSession(at end: Date) async {
        guard let id = openSession?.id else { return }
        openSession = nil
        await perform { try await repository.close(id: id, at: end) }
    }

    private func perform(_ work: () async throws -> Void) async {
        do { try await work() } catch { errorMessage = error.localizedDescription }
    }

    // MARK: Heartbeat

    private func beat() { heartbeat.lastBeat = now() }

    private func runHeartbeat() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(TrackingSettings.heartbeatInterval))
            if !Task.isCancelled { beat() }
        }
    }
}
