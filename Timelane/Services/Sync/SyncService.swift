import Foundation

/// Keeps projects and time entries in step with iCloud: owns the on/off state, feeds local changes to the
/// engine and applies what the engine downloads. All SQL is behind `SyncStore`; all CloudKit behind `SyncEngineClient`.
/// Sync is off by default; while it is off nothing here runs and the app behaves as without it.
@MainActor @Observable
final class SyncService {
    var isEnabled = false
    var lastSync: Date?
    /// A message for the Settings window after sync turned itself off (sign-out, account switch, iCloud reset).
    var notice: String?
    /// Set when a conflict removed the customer id of a project (C3).
    var customIdNotice: String?
    var isSyncing = false
    var pauseReason: String?
    var errorMessage: String?
    var hasRecordsFromNewerApp = false

    var status: SyncStatus {
        guard isEnabled else { return .off }
        if let pauseReason { return .paused(reason: pauseReason) }
        if let errorMessage { return .error(errorMessage) }
        if hasRecordsFromNewerApp { return .needsAppUpdate }
        return isSyncing ? .syncing : .idle(lastSync: lastSync)
    }

    let store: any SyncStore
    let engine: any SyncEngineClient
    let isolated: Bool
    let forwardDelay: Duration
    let onRemoteEntryChanges: @MainActor (Set<Int64>) -> Void
    @ObservationIgnored var forwarder: SyncOutboxForwarder?
    @ObservationIgnored var outboxTask: Task<Void, Never>?
    @ObservationIgnored var isEngineRunning = false
    @ObservationIgnored var isResettingZone = false
    @ObservationIgnored var zoneResetPending = false
    @ObservationIgnored var eventCount = 0

    /// - Parameters:
    ///   - isolated: tests, previews and screenshot runs never start the engine.
    ///   - forwardDelay: how long a changed record waits before it is handed to the engine (D6).
    ///   - onRemoteEntryChanges: told which local time entries a remote change touched (E1: forget undo steps).
    init(store: any SyncStore, engine: any SyncEngineClient, isolated: Bool = false, forwardDelay: Duration = .seconds(10),
         onRemoteEntryChanges: @escaping @MainActor (Set<Int64>) -> Void = { _ in }) {
        self.store = store
        self.engine = engine
        self.isolated = isolated
        self.forwardDelay = forwardDelay
        self.onRemoteEntryChanges = onRemoteEntryChanges
    }

    /// Call once at launch: restores the on/off state and starts the engine when sync is on.
    func load() async {
        guard !isolated else { return }
        let enabled = (try? await store.state(.enabled)) ?? nil
        isEnabled = enabled != nil
        if let data = (try? await store.state(.lastSync)) ?? nil, let text = String(data: data, encoding: .utf8),
           let seconds = Double(text) {
            lastSync = Date(timeIntervalSince1970: seconds)
        }
        if isEnabled { await startEngine() }
    }

    func startEngine() async {
        guard !isolated, !isEngineRunning else { return }
        await engine.setEventHandler { [weak self] event in await self?.handle(event) }
        await engine.setRecordProvider { [weak self] id in await self?.uploadRecord(for: id) }
        do {
            let state = try await store.state(.engineState)
            try await engine.start(stateSerialization: state)
            isEngineRunning = true
            // The engine keeps its own pending list, but a relaunch or a failed hand-over may have lost some.
            await forward((try? await store.pendingOutbox()) ?? [])
            beginForwardingOutbox()
        } catch {
            report(error)
        }
    }

    func stopEngine() async {
        outboxTask?.cancel()
        outboxTask = nil
        forwarder = nil
        if isEngineRunning { await engine.stop() }
        isEngineRunning = false
    }

    // MARK: Engine plumbing

    func uploadRecord(for id: SyncRecordID) async -> SyncUploadRecord? {
        (try? await store.uploadRecord(for: id)) ?? nil
    }

    /// Adds the outbox rows to the engine's pending changes.
    func forward(_ items: [SyncOutboxItem]) async {
        let saves = items.filter { $0.kind == .save }.map(\.id)
        let deletes = items.filter { $0.kind == .delete }.map(\.id)
        if !saves.isEmpty { await engine.addPendingSaves(saves) }
        if !deletes.isEmpty { await engine.addPendingDeletes(deletes) }
    }

    private func beginForwardingOutbox() {
        forwarder = SyncOutboxForwarder(delay: forwardDelay) { [weak self] items in await self?.forward(items) }
        outboxTask = Task { [weak self, store] in
            for await items in store.observeOutbox() {
                guard let self else { return }
                self.forwarder?.submit(items)
            }
        }
    }

    func markSynced() async {
        let now = Date.now
        lastSync = now
        pauseReason = nil
        errorMessage = nil
        try? await store.setState(.lastSync, Data(String(now.timeIntervalSince1970).utf8))
    }

    func report(_ error: Error) {
        switch error as? SyncEngineError {
        case .some(.offline): pauseReason = "Waiting for network"
        case .some(.quotaExceeded): pauseReason = "iCloud storage is full"
        default: errorMessage = error.localizedDescription
        }
    }
}
