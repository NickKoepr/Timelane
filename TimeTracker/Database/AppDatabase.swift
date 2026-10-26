import Foundation
import GRDB
import os

/// Owns the SQLite connection. Repositories receive this and never open files themselves.
final class AppDatabase: Sendable {
    let writer: any DatabaseWriter

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TimeTracker", category: "database")

    init(writer: any DatabaseWriter) throws {
        self.writer = writer
        try Migrations.makeMigrator().migrate(writer)
    }

    /// `Application Support/TimeTracker/db.sqlite` (inside the sandbox container).
    static func live() throws -> AppDatabase {
        let directory = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("TimeTracker", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let queue = try DatabaseQueue(path: directory.appendingPathComponent("db.sqlite").path)
        return try AppDatabase(writer: queue)
    }

    /// A database in a regular file, e.g. for tests that reopen it.
    static func file(at url: URL) throws -> AppDatabase {
        try AppDatabase(writer: try DatabaseQueue(path: url.path))
    }

    /// For tests and previews.
    static func inMemory() throws -> AppDatabase {
        try AppDatabase(writer: try DatabaseQueue())
    }

    /// Wraps a GRDB `ValueObservation` in an `AsyncStream` so callers never see GRDB types.
    func stream<Value: Sendable>(_ fetch: @escaping @Sendable (Database) throws -> Value) -> AsyncStream<Value> {
        let observation = ValueObservation.tracking(fetch)
        let writer = self.writer
        return AsyncStream { continuation in
            let task = Task {
                do {
                    for try await value in observation.values(in: writer) {
                        continuation.yield(value)
                    }
                } catch {
                    // The stream ends; the owner of the stream restarts observation if needed.
                    if !(error is CancellationError) {
                        Self.logger.error("Database observation failed: \(String(describing: error), privacy: .public)")
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
