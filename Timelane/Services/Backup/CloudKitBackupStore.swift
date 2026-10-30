import CloudKit
import Foundation

/// The live store: one `DatabaseBackup` record named `latest` in the private database of the iCloud container.
/// The container is created on first use, never earlier: without the iCloud entitlement (unit tests,
/// ad-hoc CI builds) creating a `CKContainer` crashes.
actor CloudKitBackupStore: CloudBackupStore {
    static let containerIdentifier = "iCloud.nl.nickkoepr.timelane"
    private static let recordType = "DatabaseBackup"
    private static let recordID = CKRecord.ID(recordName: "latest")

    private var cachedContainer: CKContainer?

    private var container: CKContainer {
        if let cachedContainer { return cachedContainer }
        let created = CKContainer(identifier: Self.containerIdentifier)
        cachedContainer = created
        return created
    }

    func accountStatus() async throws -> CloudAccountStatus {
        switch try await container.accountStatus() {
        case .available: .available
        case .noAccount: .noAccount
        case .restricted: .restricted
        case .temporarilyUnavailable: .temporarilyUnavailable
        case .couldNotDetermine: .couldNotDetermine
        @unknown default: .couldNotDetermine
        }
    }

    func latestBackup() async throws -> BackupInfo? {
        guard let record = try await fetchRecord() else { return nil }
        return try Self.info(from: record)
    }

    func upload(_ file: URL, info: BackupInfo) async throws {
        let record = CKRecord(recordType: Self.recordType, recordID: Self.recordID)
        record["database"] = CKAsset(fileURL: file)
        record["createdAt"] = info.createdAt
        record["deviceName"] = info.deviceName
        record["appVersion"] = info.appVersion
        record["schemaVersion"] = info.schemaVersion
        record["projectCount"] = Int64(info.projectCount)
        record["timeEntryCount"] = Int64(info.timeEntryCount)
        // `.allKeys` overwrites the stored record without a change-tag conflict.
        let result = try await container.privateCloudDatabase.modifyRecords(
            saving: [record], deleting: [], savePolicy: .allKeys)
        for saved in result.saveResults.values { _ = try saved.get() }
    }

    func download() async throws -> (file: URL, info: BackupInfo)? {
        guard let record = try await fetchRecord() else { return nil }
        let info = try Self.info(from: record)
        guard let source = (record["database"] as? CKAsset)?.fileURL else { throw BackupError.notATimelaneDatabase }
        // CloudKit deletes its asset file later, so hand out a copy in a directory the caller owns.
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimelaneBackup", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("download.sqlite")
        try FileManager.default.copyItem(at: source, to: file)
        return (file, info)
    }

    private func fetchRecord() async throws -> CKRecord? {
        do {
            return try await container.privateCloudDatabase.record(for: Self.recordID)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    private static func info(from record: CKRecord) throws -> BackupInfo {
        guard let createdAt = record["createdAt"] as? Date,
              let projects = record["projectCount"] as? Int64,
              let entries = record["timeEntryCount"] as? Int64 else { throw BackupError.notATimelaneDatabase }
        return BackupInfo(
            createdAt: createdAt, deviceName: record["deviceName"] as? String ?? "Mac",
            appVersion: record["appVersion"] as? String ?? "", schemaVersion: record["schemaVersion"] as? String ?? "",
            projectCount: Int(projects), timeEntryCount: Int(entries))
    }
}
