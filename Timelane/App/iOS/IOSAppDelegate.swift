#if os(iOS)
import Observation
import UIKit

/// iOS counterpart of the Mac `AppDelegate`: loads sync and receives the silent CloudKit pushes.
/// There is no tracking on iOS, so nothing else is started here.
final class IOSAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        guard !AppEnvironment.isIsolatedRun else { return true }
        // `backup.run()` never returns (it loops), so it gets its own task; awaiting it first kept sync from loading.
        Task { @MainActor in
            await AppEnvironment.shared.sync.load()
            Self.watchSyncEnabled()
            await MainActor.run { AppEnvironment.shared.runICloudMigration() }
        }
        Task { @MainActor in await AppEnvironment.shared.backup.run() }
        return true
    }

    /// The app is leaving the screen: send what is still pending before iOS suspends it.
    @MainActor
    static func syncBeforeSuspending() {
        let task = BackgroundTask()
        task.begin()
        Task { @MainActor in
            await AppEnvironment.shared.sync.syncNow()
            task.end()
        }
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
/// A `UIApplication` background task that is ended once, by whichever comes first: the work or the expiry.
@MainActor
private final class BackgroundTask {
    private var identifier = UIBackgroundTaskIdentifier.invalid

    func begin() {
        identifier = UIApplication.shared.beginBackgroundTask(withName: "Timelane sync") { [weak self] in
            MainActor.assumeIsolated { self?.end() }
        }
    }

    func end() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}
#endif
