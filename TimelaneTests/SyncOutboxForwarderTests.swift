import Foundation
import Testing
@testable import Timelane

@MainActor
final class ForwardedLog {
    var batches: [[SyncOutboxItem]] = []
}

@MainActor
struct SyncOutboxForwarderTests {
    private let id = SyncRecordID(recordType: .timeEntry, syncId: SyncFixtures.uuid(1))

    @Test func repeatedChangesToOneRecordAreForwardedOncePerWindow() async throws {      // D6
        let log = ForwardedLog()
        let forwarder = SyncOutboxForwarder(delay: .milliseconds(150)) { items in log.batches.append(items) }
        let item = SyncOutboxItem(id: id, kind: .save)

        for _ in 0..<5 {
            forwarder.submit([item])
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(log.batches.isEmpty)
        try await Task.sleep(for: .milliseconds(500))
        #expect(log.batches.count == 1)

        forwarder.submit([item])                       // a later change opens a new window
        try await Task.sleep(for: .milliseconds(500))
        #expect(log.batches.count == 2)
    }

    @Test func deletesAreForwardedAtOnce() async throws {
        let log = ForwardedLog()
        let forwarder = SyncOutboxForwarder(delay: .seconds(60)) { items in log.batches.append(items) }
        forwarder.submit([SyncOutboxItem(id: id, kind: .delete)])
        try await Task.sleep(for: .milliseconds(100))
        #expect(log.batches.count == 1)
    }

    @Test func serviceHandsLocalChangesToTheEngineAfterTheDelay() async throws {
        let device = try SyncTestDevice(server: InMemorySyncServer())
        try await device.service.enable(.replaceICloud)
        try await device.insertProject("Alpha", created: SyncFixtures.t(0))

        for _ in 0..<50 where device.engine.pendingSaveCount == 0 { try await Task.sleep(for: .milliseconds(20)) }
        #expect(device.engine.pendingSaveCount == 1)
    }
}
