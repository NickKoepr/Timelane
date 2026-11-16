import Foundation

enum BackupError: LocalizedError, Equatable {
    case iCloudUnavailable(CloudAccountStatus)
    case noBackup
    /// The backup was made by a newer version of the app than this one.
    case newerSchema
    case notATimelaneDatabase
    /// A backup of projects and hours waits until this device is caught up with iCloud sync.
    case waitingForSync

    private static var settingsAppName: String {
        #if os(macOS)
        "System Settings"
        #else
        "Settings"
        #endif
    }

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable(.restricted):
            "iCloud is restricted on this device, so Timelane cannot back up."
        case .iCloudUnavailable(.temporarilyUnavailable):
            "iCloud is temporarily unavailable. Try again later."
        case .iCloudUnavailable(.couldNotDetermine):
            "Timelane could not reach iCloud. Try again later."
        case .iCloudUnavailable:
            "Sign in to iCloud in \(Self.settingsAppName) to use iCloud."
        case .noBackup:
            "There is no backup in iCloud yet."
        case .newerSchema:
            "This backup was made by a newer version of Timelane. Update Timelane to restore it."
        case .notATimelaneDatabase:
            "The backup in iCloud is not a valid Timelane database."
        case .waitingForSync:
            "Waiting for iCloud to finish syncing. Try again in a moment."
        }
    }
}
