import Foundation

/// Deterministic project clean-up after a sync batch. Same input gives the same plan on every device,
/// and applying the plan leaves nothing to do (idempotent).
enum ProjectConflictResolver {
    /// C1 vs C2 cannot be told apart from the data alone (whether both devices created the project
    /// independently is unknown). The rule: two projects with the same name (case-insensitive) whose
    /// `createdAt` lie within 24 hours of the oldest one are merged (C1); a project that was created
    /// further apart is a different, older project that was renamed onto this name and is renamed
    /// with a numeric suffix (C2).
    static let mergeWindow: TimeInterval = 24 * 3600

    static func resolve(_ projects: [SyncProjectSnapshot]) -> ProjectConflictPlan {
        let sorted = projects.sorted { $0.syncId.uuidString < $1.syncId.uuidString }
        var plan = ProjectConflictPlan()
        var removed = Set<UUID>()
        var usedNames = Set(sorted.map { $0.fields.name.lowercased() })

        let byName = Dictionary(grouping: sorted) { $0.fields.name.lowercased() }
        for key in byName.keys.sorted() {
            let group = byName[key] ?? []
            guard group.count > 1 else { continue }

            let oldestFirst = group.sorted { lhs, rhs in
                if lhs.fields.createdAt != rhs.fields.createdAt { return lhs.fields.createdAt < rhs.fields.createdAt }
                return lhs.syncId.uuidString < rhs.syncId.uuidString
            }
            let survivor = oldestFirst[0]
            var keepers = [survivor]
            for other in oldestFirst.dropFirst() {
                if other.fields.createdAt.timeIntervalSince(survivor.fields.createdAt) <= mergeWindow {
                    plan.merges.append(.init(loser: other.syncId, survivor: survivor.syncId))
                    removed.insert(other.syncId)
                } else {
                    keepers.append(other)
                }
            }

            // C2: the project with the oldest `updatedAt` keeps the name, the others get a suffix.
            let losers = keepers.sorted(by: updatedAtOrder).dropFirst()
            for loser in losers {
                let newName = firstFreeName(base: loser.fields.name, used: usedNames)
                usedNames.insert(newName.lowercased())
                plan.renames.append(.init(syncId: loser.syncId, newName: newName))
            }
        }

        // C3: the same customId on several remaining projects; the oldest `updatedAt` keeps it.
        let remaining = sorted.filter { !removed.contains($0.syncId) }
        let byCustomId = Dictionary(grouping: remaining) { snapshot -> String in
            snapshot.fields.customId?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
        }
        for key in byCustomId.keys.sorted() where !key.isEmpty {
            let group = byCustomId[key] ?? []
            guard group.count > 1 else { continue }
            plan.clearedCustomIds += group.sorted(by: updatedAtOrder).dropFirst().map(\.syncId)
        }
        plan.clearedCustomIds.sort { $0.uuidString < $1.uuidString }
        return plan
    }

    /// Older `updatedAt` first; equal times: smaller `syncId` first (so the larger one loses).
    private static func updatedAtOrder(_ lhs: SyncProjectSnapshot, _ rhs: SyncProjectSnapshot) -> Bool {
        if lhs.fields.updatedAt != rhs.fields.updatedAt { return lhs.fields.updatedAt < rhs.fields.updatedAt }
        return lhs.syncId.uuidString < rhs.syncId.uuidString
    }

    private static func firstFreeName(base: String, used: Set<String>) -> String {
        var number = 2
        while used.contains("\(base) (\(number))".lowercased()) { number += 1 }
        return "\(base) (\(number))"
    }
}
