/// The iCloud account state, without leaking CloudKit types outside `CloudKitBackupStore`.
enum CloudAccountStatus: Sendable, Equatable {
    case available
    case noAccount
    case restricted
    case temporarilyUnavailable
    case couldNotDetermine
}
