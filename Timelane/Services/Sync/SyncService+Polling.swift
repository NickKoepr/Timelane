import Foundation

/// CloudKit pushes are best effort and often arrive late or not at all (seen in practice: changes from another
/// device only showed up when the app came to the foreground). While the app is on screen it therefore also
/// asks iCloud for changes every few seconds; a fetch without changes is two small requests.
extension SyncService {
    static let activePollInterval: Duration = .seconds(15)
    /// The Mac keeps running (menu bar) when it is not the active app; check less often then.
    static let inactivePollInterval: Duration = .seconds(60)

    /// Starts, changes or (with nil) stops the periodic sync. A no-op while sync is off: each tick checks again.
    func setPollInterval(_ interval: Duration?) {
        pollTask?.cancel()
        pollTask = nil
        guard let interval, !isolated else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled, let self else { return }
                await syncNow()     // returns at once while sync is off
            }
        }
    }
}
