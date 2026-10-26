import Foundation

/// Remembers "the app was alive at this time", to close sessions left open by a crash.
protocol HeartbeatStore: AnyObject {
    var lastBeat: Date? { get set }
}

final class UserDefaultsHeartbeat: HeartbeatStore {
    private let key = "trackingHeartbeat"

    var lastBeat: Date? {
        get { UserDefaults.standard.object(forKey: key) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
