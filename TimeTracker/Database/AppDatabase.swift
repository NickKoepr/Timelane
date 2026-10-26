import Foundation
import GRDB

/// Owns the SQLite connection. Repositories receive this and never open files themselves.
final class AppDatabase: Sendable {
    let writer: any DatabaseWriter

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
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
