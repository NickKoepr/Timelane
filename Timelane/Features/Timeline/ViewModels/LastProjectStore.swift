import Foundation

/// Remembers the last project used to register time, so it can be preselected.
struct LastProjectStore {
    private let key = "lastUsedProjectId"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var projectId: Int64? {
        get { defaults.object(forKey: key) as? Int64 }
        nonmutating set { defaults.set(newValue, forKey: key) }
    }
}
