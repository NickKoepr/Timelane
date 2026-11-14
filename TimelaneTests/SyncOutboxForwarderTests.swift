import Foundation
import Testing
@testable import Timelane

@MainActor
final class ForwardedLog {
    var batches: [[SyncOutboxItem]] = []
}

/// Replaces the forwarder's wait: every sleep suspends until the test calls `fire()`.
@MainActor
final class ManualSleeper {
    private var waiters: [CheckedContinuation<Void, Never>] = []
    var waiterCount: Int { waiters.count }

    func sleep() async {
        await withCheckedContinuation { waiters.append($0) }
    }

    func fire() {
        let current = waiters
        waiters = []
        for waiter in current { waiter.resume() }
    }
}

/// Lets queued main-actor work run until `condition` holds (bounded, so a bug fails instead of hanging).
@MainActor
func settle(until condition: @MainActor () -> Bool) async {
    for _ in 0..<5_000 where !condition() { await Task.yield() }
}

@MainActor
struct SyncOutboxForwarderTests {
    private let id = SyncRecordID(recordType: .timeEntry, syncId: SyncFixtures.uuid(1))

    @Test func repeatedChangesToOneRecordAreForwardedOncePerWindow() async throws {      // D6
        let log = ForwardedLog()
        let sleeper = ManualSleeper()
        let forwarder = SyncOutboxForwarder(delay: .seconds(10), sleep: { _ in await sleeper.sleep() }) { items in
            log.batches.append(items)
        }
        let item = SyncOutboxItem(id: id, kind: .save)

        for _ in 0..<5 { forwarder.submit([item]) }
        await settle { sleeper.waiterCount >= 1 }
        #expect(sleeper.waiterCount == 1)              // one timer for five changes
        #expect(log.batches.isEmpty)

        sleeper.fire()
        await settle { log.batches.count >= 1 }
        #expect(log.batches.count == 1)

        forwarder.submit([item])                       // a later change opens a new window
        await settle { sleeper.waiterCount >= 1 }
        #expect(log.batches.count == 1)
        sleeper.fire()
        await settle { log.batches.count >= 2 }
        #expect(log.batches.count == 2)
    }

    @Test func deletesAreForwardedAtOnce() async throws {
        let log = ForwardedLog()
        let sleeper = ManualSleeper()
        let forwarder = SyncOutboxForwarder(delay: .seconds(60), sleep: { _ in await sleeper.sleep() }) { items in
            log.batches.append(items)
        }
        forwarder.submit([SyncOutboxItem(id: id, kind: .delete)])
        await settle { log.batches.count >= 1 }
        #expect(log.batches.count == 1)
        #expect(sleeper.waiterCount == 0)
    }

    @Test func serviceHandsLocalChangesToTheEngineAfterTheDelay() async throws {
        let device = try SyncTestDevice(server: InMemorySyncServer())
        try await device.service.enable(.replaceICloud)
        try await device.insertProject("Alpha", created: SyncFixtures.t(0))

        // The outbox observation runs off the main actor; poll with a generous upper bound.
        for _ in 0..<400 where device.engine.pendingSaveCount == 0 { try await Task.sleep(for: .milliseconds(25)) }
        #expect(device.engine.pendingSaveCount == 1)
    }
}
