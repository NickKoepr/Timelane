import Foundation

enum BackupError: LocalizedError, Equatable {
    case iCloudUnavailable(CloudAccountStatus)
    case noBackup
    /// The backup was made by a newer version of the app than this one.
    case newerSchema
    case notATimelaneDatabase

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable(.restricted):
            "iCloud is restricted on this Mac, so Timelane cannot back up."
        case .iCloudUnavailable(.temporarilyUnavailable):
            "iCloud is temporarily unavailable. Try again later."
        case .iCloudUnavailable(.couldNotDetermine):
            "Timelane could not reach iCloud. Try again later."
        case .iCloudUnavailable:
            "Sign in to iCloud in System Settings to use iCloud backup."
        case .noBackup:
            "There is no backup in iCloud yet."
        case .newerSchema:
            "This backup was made by a newer version of Timelane. Update Timelane to restore it."
        case .notATimelaneDatabase:
            "The backup in iCloud is not a valid Timelane database."
        }
    }
}
