import Foundation

/// Converts between local models and the plain sync values. Local `Int64` ids never leave the device:
/// time entries refer to their project by `syncId`.
enum SyncRecordMapping {
    static func fields(for project: Project) -> ProjectFields {
        ProjectFields(name: project.name, colorHex: project.colorHex, isArchived: project.isArchived,
                      createdAt: project.createdAt, customId: project.customId, updatedAt: project.updatedAt)
    }

    static func project(from fields: ProjectFields, syncId: UUID, localId: Int64?) -> Project {
        Project(id: localId, name: fields.name, colorHex: fields.colorHex, isArchived: fields.isArchived,
                createdAt: fields.createdAt, customId: fields.customId, syncId: syncId,
                updatedAt: fields.updatedAt)
    }

    static func fields(for row: SyncTimeEntryRow, projectSyncId: UUID) -> TimeEntryFields {
        let entry = row.entry
        return TimeEntryFields(projectSyncId: projectSyncId, start: entry.start, end: entry.end,
                               title: entry.title, note: entry.note, createdAt: entry.createdAt,
                               updatedAt: entry.updatedAt, timesUpdatedAt: row.timesUpdatedAt,
                               textUpdatedAt: row.textUpdatedAt, projectUpdatedAt: row.projectUpdatedAt)
    }

    /// Returns nil when `projectId` does not know the project yet; the caller parks the record.
    static func row(from fields: TimeEntryFields, syncId: UUID, localId: Int64?,
                    projectId: (UUID) -> Int64?) -> SyncTimeEntryRow? {
        guard let localProjectId = projectId(fields.projectSyncId) else { return nil }
        let entry = TimeEntry(id: localId, projectId: localProjectId, start: fields.start, end: fields.end,
                              title: fields.title, note: fields.note, createdAt: fields.createdAt,
                              updatedAt: fields.updatedAt, syncId: syncId)
        return SyncTimeEntryRow(entry: entry, timesUpdatedAt: fields.timesUpdatedAt,
                                textUpdatedAt: fields.textUpdatedAt, projectUpdatedAt: fields.projectUpdatedAt)
    }
}
