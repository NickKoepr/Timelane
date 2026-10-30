import Foundation
import os

/// Fake remote for tests and previews: keeps the snapshot in memory and counts calls.
final class InMemoryCloudBackupStore: CloudBackupStore, @unchecked Sendable {
    private struct State {
        var status: CloudAccountStatus = .available
        var data: Data?
        var info: BackupInfo?
        var error: (any Error)?
        var uploadCount = 0
        var downloadCount = 0
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
    var info: BackupInfo? { state.withLock { $0.info } }
    var storedData: Data? { state.withLock { $0.data } }
    var uploadCount: Int { state.withLock { $0.uploadCount } }
    var downloadCount: Int { state.withLock { $0.downloadCount } }

    /// Seeds a backup without going through `upload`.
    func seed(data: Data, info: BackupInfo) {
        state.withLock { $0.data = data; $0.info = info }
    }

    private func throwIfFailing() throws {
        if let error = state.withLock({ $0.error }) { throw error }
    }

    func accountStatus() async throws -> CloudAccountStatus {
        try throwIfFailing()
        return status
    }

    func latestBackup() async throws -> BackupInfo? {
        try throwIfFailing()
        return info
    }

    func upload(_ file: URL, info: BackupInfo) async throws {
        try throwIfFailing()
        let data = try Data(contentsOf: file)
        state.withLock { $0.data = data; $0.info = info; $0.uploadCount += 1 }
    }

    func download() async throws -> (file: URL, info: BackupInfo)? {
        try throwIfFailing()
        guard let (data, info) = state.withLock({ state in state.data.flatMap { data in state.info.map { (data, $0) } } }) else {
            return nil
        }
        state.withLock { $0.downloadCount += 1 }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimelaneBackup", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("download.sqlite")
        try data.write(to: file)
        return (file, info)
    }
}
