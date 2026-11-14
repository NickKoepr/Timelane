import Foundation
import Testing
@testable import Timelane

struct SyncDeleteDecisionTests {
    // B3: delete wins.
    @Test func remoteDeleteRemovesLocalRow() {
        #expect(SyncDeleteDecision.forRemoteDelete(recordType: .timeEntry, existsLocally: true, dependentEntryCount: 0) == .deleteLocal)
        #expect(SyncDeleteDecision.forRemoteDelete(recordType: .project, existsLocally: true, dependentEntryCount: 0) == .deleteLocal)
    }

    @Test func pendingLocalDeleteIgnoresIncomingEdit() {
        #expect(SyncDeleteDecision.forRemoteSave(hasPendingLocalDelete: true) == .ignore)
        #expect(SyncDeleteDecision.forRemoteSave(hasPendingLocalDelete: false) == .apply)
    }

    // B4: deleted on both.
    @Test func deleteOfMissingRowIsHarmless() {
        #expect(SyncDeleteDecision.forRemoteDelete(recordType: .timeEntry, existsLocally: false, dependentEntryCount: 0) == .alreadyGone)
        #expect(SyncDeleteDecision.deleteFailureCountsAsSuccess(isUnknownItem: true))
        #expect(!SyncDeleteDecision.deleteFailureCountsAsSuccess(isUnknownItem: false))
    }

    // C4: entry wins over a project delete.
    @Test func projectWithEntriesIsResurrected() {
        #expect(SyncDeleteDecision.forRemoteDelete(recordType: .project, existsLocally: true, dependentEntryCount: 2) == .resurrect)
    }

    @Test func entryForMissingProjectUsesTombstoneOrParks() {
        #expect(SyncDeleteDecision.forEntryWithMissingProject(hasTombstone: true) == .resurrectFromTombstone)
        #expect(SyncDeleteDecision.forEntryWithMissingProject(hasTombstone: false) == .park)
    }
}
