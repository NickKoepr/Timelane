import Foundation
import Testing
@testable import Timelane

struct SyncRecordMappingTests {
    typealias F = SyncFixtures

    @Test func projectRoundTrips() {
        let project = Project(id: 4, name: "Alpha", colorHex: "#34C759", isArchived: true, createdAt: F.t(10),
                              customId: "A-1", syncId: F.uuid(1), updatedAt: F.t(99))
        let fields = SyncRecordMapping.fields(for: project)
        #expect(fields.updatedAt == F.t(99))
        #expect(fields.schemaVersion == 1)
        #expect(SyncRecordMapping.project(from: fields, syncId: F.uuid(1), localId: 4) == project)
    }

    @Test func timeEntryRoundTrips() {
        let entry = TimeEntry(id: 8, projectId: 3, start: F.t(0), end: F.t(3600), title: "T", note: "N",
                              createdAt: F.t(5), updatedAt: F.t(50), syncId: F.uuid(2))
        let row = SyncTimeEntryRow(entry: entry, timesUpdatedAt: F.t(50), textUpdatedAt: F.t(40),
                                   projectUpdatedAt: F.t(5))
        let fields = SyncRecordMapping.fields(for: row, projectSyncId: F.uuid(77))
        #expect(fields.projectSyncId == F.uuid(77))
        #expect(fields.textUpdatedAt == F.t(40))

        let back = SyncRecordMapping.row(from: fields, syncId: F.uuid(2), localId: 8) { $0 == F.uuid(77) ? 3 : nil }
        #expect(back == row)
    }

    @Test func unknownProjectReturnsNil() {
        let fields = F.entry(start: 1, end: 2)
        #expect(SyncRecordMapping.row(from: fields, syncId: F.uuid(1), localId: nil) { _ in nil } == nil)
    }

    @Test func recordTypeFollowsFieldsAndSurvivesCodable() throws {
        let project = SyncRecord(syncId: F.uuid(1), project: F.project("A"))
        let entry = SyncRecord(syncId: F.uuid(2), timeEntry: F.entry(start: 1, end: 2, title: "x"))
        #expect(project.recordType == .project)
        #expect(entry.recordType == .timeEntry)
        for record in [project, entry] {
            let data = try JSONEncoder().encode(record)
            #expect(try JSONDecoder().decode(SyncRecord.self, from: data) == record)
        }
    }
}
