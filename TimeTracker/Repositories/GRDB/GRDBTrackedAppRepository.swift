import Foundation
import GRDB

struct GRDBTrackedAppRepository: TrackedAppRepository {
    let database: AppDatabase

    func observeTrackedApps() -> AsyncStream<[TrackedApp]> {
        database.stream { db in try Self.fetch(db) }
    }

    func trackedApps() async throws -> [TrackedApp] {
        try await database.writer.read { db in try Self.fetch(db) }
    }

    func add(_ apps: [TrackedApp]) async throws {
        try await database.writer.write { db in
            for app in apps {
                let exists = try TrackedApp.filter(Column("bundleIdentifier") == app.bundleIdentifier).fetchCount(db) > 0
                if !exists {
                    var copy = app
                    copy.id = nil
                    try copy.insert(db)
                }
            }
        }
    }

    func remove(id: Int64) async throws {
        try await database.writer.write { db in _ = try TrackedApp.deleteOne(db, id: id) }
    }

    private static func fetch(_ db: Database) throws -> [TrackedApp] {
        try TrackedApp.order(Column("name").collating(.nocase)).fetchAll(db)
    }
}
