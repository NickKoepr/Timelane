import Foundation
@testable import Timelane

/// Builders for the pure sync tests. Dates are whole seconds so they survive any round trip.
enum SyncFixtures {
    static func uuid(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!
    }

    static func t(_ seconds: Double) -> Date { Date(timeIntervalSince1970: 1_800_000_000 + seconds) }

    static let hour: Double = 3600

    static func project(_ name: String, created: Double = 0, updated: Double? = nil, color: String = "#4F8EF7",
                        archived: Bool = false, customId: String? = nil) -> ProjectFields {
        ProjectFields(name: name, colorHex: color, isArchived: archived, createdAt: t(created),
                      customId: customId, updatedAt: t(updated ?? created))
    }

    static func snapshot(_ n: Int, _ fields: ProjectFields) -> SyncProjectSnapshot {
        SyncProjectSnapshot(localId: Int64(n), syncId: uuid(n), fields: fields)
    }

    /// Entry from `startHour` to `endHour` (hours after the fixture epoch); all groups changed at `at`.
    static func entry(start startHour: Double, end endHour: Double, at: Double = 0, project: Int = 100,
                      title: String? = nil, note: String? = nil) -> TimeEntryFields {
        TimeEntryFields(projectSyncId: uuid(project), start: t(startHour * hour), end: t(endHour * hour),
                        title: title, note: note, createdAt: t(at), updatedAt: t(at),
                        timesUpdatedAt: t(at), textUpdatedAt: t(at), projectUpdatedAt: t(at))
    }

    static func settler(_ n: Int, _ fields: TimeEntryFields) -> SyncSettlerEntry {
        SyncSettlerEntry(syncId: uuid(n), fields: fields)
    }

    /// Applies a settlement to the input, as the caller would.
    static func apply(_ settlement: TimeEntrySettlement, to entries: [SyncSettlerEntry]) -> [SyncSettlerEntry] {
        var byId = Dictionary(uniqueKeysWithValues: entries.map { ($0.syncId, $0) })
        for id in settlement.deletes { byId[id] = nil }
        for save in settlement.saves { byId[save.syncId] = save }
        return byId.values.sorted { $0.syncId.uuidString < $1.syncId.uuidString }
    }
}
