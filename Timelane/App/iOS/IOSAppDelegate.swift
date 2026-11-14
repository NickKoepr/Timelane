#if os(iOS)
import Observation
import UIKit

/// iOS counterpart of the Mac `AppDelegate`: loads sync and receives the silent CloudKit pushes.
/// There is no tracking on iOS, so nothing else is started here.
final class IOSAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        guard !AppEnvironment.isIsolatedRun else { return true }
        Task { @MainActor in
            await AppEnvironment.shared.backup.run()
            await AppEnvironment.shared.sync.load()
            Self.watchSyncEnabled()
        }
        return true
    }

    /// A silent push from iCloud: the sync engine handles it itself, a sync pass is a cheap extra.
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        guard !AppEnvironment.isIsolatedRun else { return .noData }
        await AppEnvironment.shared.sync.syncNow()
        return .newData
    }

    /// Registers for pushes whenever sync is (or becomes) enabled, so changes from other devices arrive quickly.
    @MainActor
    private static func watchSyncEnabled() {
        let sync = AppEnvironment.shared.sync
        if sync.isEnabled { UIApplication.shared.registerForRemoteNotifications() }
        withObservationTracking {
            _ = sync.isEnabled
        } onChange: {
            Task { @MainActor in watchSyncEnabled() }
        }
    }
}
#endif
