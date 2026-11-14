import Foundation

/// Where the user can see synced data: the app (Mac: active app, iOS: on screen) and the Mac menu bar panel.
enum SyncPollSource: Hashable, Sendable {
    case app
    case menuBar
}

/// CloudKit pushes are best effort and often arrive late or not at all (seen in practice: changes from another
/// device only showed up when the app came to the foreground). While synced data is on screen the app therefore
/// also asks iCloud for changes once a minute, and right away when it comes on screen. Nothing polls while
/// nothing is visible; a fetch without changes is two small requests.
extension SyncService {
    /// Marks a place as visible or hidden. Becoming visible syncs at once; while anything is visible a sync
    /// runs every `pollInterval`. A no-op while sync is off (`syncNow` returns at once).
    func setPolling(_ visible: Bool, for source: SyncPollSource) {
        guard !isolated else { return }
        let wasVisible = pollSources.contains(source)
        guard visible != wasVisible else { return }
        if visible {
            pollSources.insert(source)
            Task { [weak self] in await self?.syncNow() }
        } else {
            pollSources.remove(source)
        }
        updatePollTask()
    }

    private func updatePollTask() {
        guard !pollSources.isEmpty else {
            pollTask?.cancel()
            pollTask = nil
            return
        }
        guard pollTask == nil else { return }
        pollTask = Task { [weak self, pollInterval] in
            while !Task.isCancelled {
                try? await Task.sleep(for: pollInterval)
                guard !Task.isCancelled, let self else { return }
                await syncNow()
            }
        }
    }
}
