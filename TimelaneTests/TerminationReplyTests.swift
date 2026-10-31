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

    /// Polls instead of sleeping a fixed time: on a busy CI runner the global queue can run the
    /// 50 ms timeout well after 300 ms.
    @Test func timeoutDeliversWhenNeverSent() async throws {
        let counter = Counter()
        _ = TerminationReply(timeout: 0.05) { counter.increment() }
        for _ in 0..<500 where counter.value == 0 { try await Task.sleep(for: .milliseconds(10)) }
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
