import Foundation

/// Where the running timer's start time survives app restarts.
@MainActor
protocol RecordingTimerStore: AnyObject {
    var startedAt: Date? { get set }
}

final class InMemoryRecordingTimerStore: RecordingTimerStore {
    var startedAt: Date?
    init(startedAt: Date? = nil) { self.startedAt = startedAt }
}

final class UserDefaultsRecordingTimerStore: RecordingTimerStore {
    static let key = "recordingTimer.startedAt"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var startedAt: Date? {
        get { defaults.object(forKey: Self.key) as? Date }
        set {
            if let newValue { defaults.set(newValue, forKey: Self.key) } else { defaults.removeObject(forKey: Self.key) }
        }
    }
}
