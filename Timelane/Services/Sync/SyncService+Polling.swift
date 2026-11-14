import Foundation

/// Where the user can see synced data: the app (Mac: active app, iOS: on screen) and the Mac menu bar panel.
enum SyncPollSource: Hashable, Sendable {
    case app
    case menuBar

    /// How often iCloud is asked for changes while this place is visible.
    var interval: Duration {
        switch self {
        case .app: .seconds(30)
        case .menuBar: .seconds(60)
        }
    }
}

/// CloudKit pushes are best effort and often arrive late or not at all (seen in practice: changes from another
/// device only showed up when the app came to the foreground). While synced data is on screen the app therefore
/// also asks iCloud for changes (app: every 30 s, menu bar panel: every 60 s), and right away when it comes on
/// screen. Nothing polls while nothing is visible; a check without changes is one small request.
extension SyncService {
    /// Marks a place as visible or hidden. Becoming visible syncs at once; while anything is visible a sync
    /// runs at the shortest interval of the visible places. A no-op while sync is off (`syncNow` returns at once).
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
        let interval = pollSources.isEmpty ? nil : pollIntervalOverride ?? pollSources.map(\.interval).min()
        guard interval != pollTaskInterval else { return }
        pollTask?.cancel()
        pollTask = nil
        pollTaskInterval = interval
        guard let interval else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled, let self else { return }
                await syncNow()
            }
        }
    }
}
