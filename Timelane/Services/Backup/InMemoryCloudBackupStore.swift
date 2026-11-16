import Foundation
import os

/// Fake remote for tests and previews: keeps every part in memory and counts calls.
final class InMemoryCloudBackupStore: CloudBackupStore, @unchecked Sendable {
    private struct Stored {
        var data: Data
        var info: BackupInfo
    }

    private struct State {
        var status: CloudAccountStatus = .available
        var parts: [BackupPart: Stored] = [:]
        var error: (any Error)?
        var uploads: [BackupPart] = []
        var downloads: [BackupPart] = []
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    init(status: CloudAccountStatus = .available) {
        state.withLock { $0.status = status }
    }

    var status: CloudAccountStatus {
        get { state.withLock { $0.status } }
        set { state.withLock { $0.status = newValue } }
    }
    /// When set, every call throws it.
    var error: (any Error)? {
        get { state.withLock { $0.error } }
        set { state.withLock { $0.error = newValue } }
    }
    func info(_ part: BackupPart) -> BackupInfo? { state.withLock { $0.parts[part]?.info } }
    func storedData(_ part: BackupPart) -> Data? { state.withLock { $0.parts[part]?.data } }
    /// Every upload, in order.
    var uploads: [BackupPart] { state.withLock { $0.uploads } }
    func uploadCount(_ part: BackupPart) -> Int { uploads.filter { $0 == part }.count }
    var downloads: [BackupPart] { state.withLock { $0.downloads } }

    /// Stores a part without going through `upload`.
    func seed(_ part: BackupPart, data: Data, info: BackupInfo) {
        state.withLock { $0.parts[part] = Stored(data: data, info: info) }
    }

    /// Stores a real database file as a part (e.g. a legacy whole-database backup).
    func seed(_ part: BackupPart, file: URL, info: BackupInfo) throws {
        seed(part, data: try Data(contentsOf: file), info: info)
    }

    private func throwIfFailing() throws {
        if let error = state.withLock({ $0.error }) { throw error }
    }

    func accountStatus() async throws -> CloudAccountStatus {
        try throwIfFailing()
        return status
    }

    func latestBackup(_ part: BackupPart) async throws -> BackupInfo? {
        try throwIfFailing()
        return info(part)
    }

    func upload(_ file: URL, info: BackupInfo, as part: BackupPart) async throws {
        try throwIfFailing()
        let data = try Data(contentsOf: file)
        state.withLock {
            $0.parts[part] = Stored(data: data, info: info)
            $0.uploads.append(part)
        }
    }

    func download(_ part: BackupPart) async throws -> (file: URL, info: BackupInfo)? {
        try throwIfFailing()
        guard let stored = state.withLock({ $0.parts[part] }) else { return nil }
        state.withLock { $0.downloads.append(part) }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimelaneBackup", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("download.sqlite")
        try stored.data.write(to: file)
        return (file, stored.info)
    }

    func delete(_ part: BackupPart) async throws {
        try throwIfFailing()
        _ = state.withLock { $0.parts.removeValue(forKey: part) }
    }
}
