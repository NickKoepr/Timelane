import Foundation

/// Remembers what the automatic logger was doing, so a restart of Timelane continues it.
protocol AutoLogStateStore: AnyObject {
    var state: AutoLogState { get set }
}

final class UserDefaultsAutoLogStateStore: AutoLogStateStore {
    private let defaults: UserDefaults
    private let key = "autoLogState"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    /// A missing or unreadable blob is an empty state.
    var state: AutoLogState {
        get { defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(AutoLogState.self, from: $0) } ?? AutoLogState() }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: key) }
    }
}

/// For tests and previews: never touches the user's defaults.
final class InMemoryAutoLogStateStore: AutoLogStateStore {
    var state = AutoLogState()
}
