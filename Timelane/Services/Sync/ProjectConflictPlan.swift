import Foundation

/// Corrections that make a set of projects consistent again. All values are `syncId`s or names, so
/// the caller maps them to local rows. Corrections must be written without bumping `updatedAt`.
struct ProjectConflictPlan: Equatable, Sendable {
    /// Move the entries (and tracked-app links) of `loser` to `survivor`, then delete `loser`.
    struct Merge: Equatable, Sendable {
        var loser: UUID
        var survivor: UUID
    }

    struct Rename: Equatable, Sendable {
        var syncId: UUID
        var newName: String
    }

    var merges: [Merge] = []
    var renames: [Rename] = []
    /// Projects that lose their `customId` because another project has the same one (shown as a notice).
    var clearedCustomIds: [UUID] = []

    var isEmpty: Bool { merges.isEmpty && renames.isEmpty && clearedCustomIds.isEmpty }
}
