import Foundation

/// Pure: which apps the user can still add to the tracked list.
enum AppCandidates {
    /// Union of running and previously seen apps, deduplicated by bundle identifier (the running
    /// app's name wins), minus tracked apps and `ownBundleId`, sorted by name.
    static func merge(running: [ForegroundApp], known: [ForegroundApp],
                      tracked: Set<String>, ownBundleId: String?) -> [ForegroundApp] {
        var byId: [String: ForegroundApp] = [:]
        for app in known + running { byId[app.bundleIdentifier] = app }
        return byId.values
            .filter { !tracked.contains($0.bundleIdentifier) && $0.bundleIdentifier != ownBundleId }
            .sorted { lhs, rhs in
                let order = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                return order == .orderedSame ? lhs.bundleIdentifier < rhs.bundleIdentifier : order == .orderedAscending
            }
    }
}
