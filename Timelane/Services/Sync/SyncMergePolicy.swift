import Foundation

/// Last-writer-wins merging of two versions of one record.
///
/// Both versions have the same `syncId`, so equal timestamps are broken by comparing the content
/// (a fixed key per field group). Every device picks the same winner whichever side is "local".
enum SyncMergePolicy {
    /// Projects: the whole record is taken from the version with the newer `updatedAt`.
    static func merge(local: ProjectFields?, remote: ProjectFields) -> ProjectFields {
        guard let local else { return remote }
        let remoteWins = remoteWins(localTime: local.updatedAt, remoteTime: remote.updatedAt,
                                    localKey: local.tiebreakKey, remoteKey: remote.tiebreakKey)
        return remoteWins ? remote : local
    }

    /// Time entries: each field group is decided on its own timestamp, so a title edit on one device
    /// and a move on the other both survive.
    static func merge(local: TimeEntryFields?, remote: TimeEntryFields) -> TimeEntryFields {
        guard let local else { return remote }
        var result = local

        if remoteWins(localTime: local.timesUpdatedAt, remoteTime: remote.timesUpdatedAt,
                      localKey: local.timesKey, remoteKey: remote.timesKey) {
            result.start = remote.start
            result.end = remote.end
            result.timesUpdatedAt = remote.timesUpdatedAt
        }
        if remoteWins(localTime: local.textUpdatedAt, remoteTime: remote.textUpdatedAt,
                      localKey: local.textKey, remoteKey: remote.textKey) {
            result.title = remote.title
            result.note = remote.note
            result.textUpdatedAt = remote.textUpdatedAt
        }
        if remoteWins(localTime: local.projectUpdatedAt, remoteTime: remote.projectUpdatedAt,
                      localKey: local.projectKey, remoteKey: remote.projectKey) {
            result.projectSyncId = remote.projectSyncId
            result.projectUpdatedAt = remote.projectUpdatedAt
        }
        result.createdAt = min(local.createdAt, remote.createdAt)
        result.updatedAt = max(result.timesUpdatedAt, result.textUpdatedAt, result.projectUpdatedAt)
        result.schemaVersion = max(local.schemaVersion, remote.schemaVersion)
        return result
    }

    private static func remoteWins(localTime: Date, remoteTime: Date, localKey: String, remoteKey: String) -> Bool {
        if remoteTime != localTime { return remoteTime > localTime }
        return remoteKey > localKey
    }
}
