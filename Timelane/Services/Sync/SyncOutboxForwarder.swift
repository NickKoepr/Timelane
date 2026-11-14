import Foundation

/// Hands outbox changes to the engine, at most once per `delay` for the same record (D6).
///
/// The AutoTimeLogger rewrites its entry every few seconds; the outbox keeps one row per record, and the
/// first change of a record starts a timer. When it fires, the record is forwarded once, and the engine
/// reads the then-current version of the record when it uploads. Deletes are forwarded at once.
@MainActor
final class SyncOutboxForwarder {
    private let delay: Duration
    private let sleep: @Sendable (Duration) async -> Void
    private let forward: @MainActor ([SyncOutboxItem]) async -> Void
    private var scheduled = Set<SyncRecordID>()

    /// `sleep` is injectable so tests can release the wait by hand.
    init(delay: Duration,
         sleep: @escaping @Sendable (Duration) async -> Void = { try? await Task.sleep(for: $0) },
         forward: @escaping @MainActor ([SyncOutboxItem]) async -> Void) {
        self.delay = delay
        self.sleep = sleep
        self.forward = forward
    }

    func submit(_ items: [SyncOutboxItem]) {
        let deletes = items.filter { $0.kind == .delete }
        if !deletes.isEmpty { Task { await forward(deletes) } }
        for item in items where item.kind == .save && !scheduled.contains(item.id) {
            scheduled.insert(item.id)
            Task { [weak self, delay, sleep] in
                await sleep(delay)
                guard let self else { return }
                self.scheduled.remove(item.id)
                await self.forward([item])
            }
        }
    }
}
