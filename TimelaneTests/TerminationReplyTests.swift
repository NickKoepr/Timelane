import Foundation
import Synchronization
import Testing
@testable import Timelane

struct TerminationReplyTests {
    private final class Counter: Sendable {
        private let count = Mutex(0)
        var value: Int { count.withLock { $0 } }
        func increment() { count.withLock { $0 += 1 } }
    }

    @Test func sendDeliversOnce() {
        let counter = Counter()
        let reply = TerminationReply(timeout: 60) { counter.increment() }
        reply.send()
        #expect(counter.value == 1)
    }

    @Test func sendingTwiceDeliversOnce() {
        let counter = Counter()
        let reply = TerminationReply(timeout: 60) { counter.increment() }
        reply.send()
        reply.send()
        #expect(counter.value == 1)
    }

    @Test func timeoutDeliversWhenNeverSent() async throws {
        let counter = Counter()
        _ = TerminationReply(timeout: 0.05) { counter.increment() }
        try await Task.sleep(for: .milliseconds(300))
        #expect(counter.value == 1)
    }

    @Test func timeoutAfterSendDoesNotDeliverAgain() async throws {
        let counter = Counter()
        let reply = TerminationReply(timeout: 0.05) { counter.increment() }
        reply.send()
        try await Task.sleep(for: .milliseconds(300))
        #expect(counter.value == 1)
    }
}
