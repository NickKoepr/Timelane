import AppKit

/// Turns `ActivityEvent`s into stored `AppSession`s. All sources feed one serial event stream.
@MainActor @Observable
final class AppActivityTracker {
    private(set) var currentApp: ForegroundApp?
    private(set) var pauseReasons: Set<PauseReason> = []
    private(set) var errorMessage: String?

    var isPaused: Bool { !pauseReasons.isEmpty }

    private let repository: any AppSessionRepository
    private let heartbeat: any HeartbeatStore
    private let now: () -> Date
    private let frontmostProvider: () -> ForegroundApp?

    private var openSession: AppSession?
    private var continuation: AsyncStream<ActivityEvent>.Continuation?
    private var tasks: [Task<Void, Never>] = []
    private var systemObserver: SystemEventObserver?
    private var idleMonitor: IdleMonitor?

    init(repository: any AppSessionRepository,
         heartbeat: any HeartbeatStore = UserDefaultsHeartbeat(),
         now: @escaping () -> Date = { .now },
         frontmostProvider: @escaping () -> ForegroundApp? = {
             NSWorkspace.shared.frontmostApplication.flatMap(ForegroundApp.init)
         }) {
        self.repository = repository
        self.heartbeat = heartbeat
        self.now = now
        self.frontmostProvider = frontmostProvider
    }

    // MARK: Lifecycle

    /// Closes leftovers from a crash, starts the first session and begins listening to the system.
    func start() async {
        guard continuation == nil else { return }
        await perform { try await repository.closeDanglingSessions(at: heartbeat.lastBeat) }
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
        }
    }

    // MARK: Sessions

    private func switchSession(to app: ForegroundApp?) async {
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
