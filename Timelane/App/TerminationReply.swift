import AppKit
import Synchronization

/// Answers `applicationShouldTerminate` (after `.terminateLater`) exactly once: when the cleanup
/// finishes or after a timeout, whichever comes first. Thread-safe, so it can be called from anywhere.
final class TerminationReply: Sendable {
    private let delivered = Mutex(false)
    private let deliver: @Sendable () -> Void

    /// The timeout starts immediately. `deliver` runs at most once, on whichever thread gets there first.
    init(timeout: TimeInterval = 2, deliver: @escaping @Sendable () -> Void = TerminationReply.replyToApp) {
        self.deliver = deliver
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [self] in send() }
    }

    func send() {
        let first = delivered.withLock { value in
            defer { value = true }
            return !value
        }
        if first { deliver() }
    }

    /// Posted as a run-loop perform block instead of a main-queue job: `terminate:` waits in a nested run
    /// loop, and a main-queue job can't run while the block that called `terminate:` is still on the stack.
    @Sendable private static func replyToApp() {
        RunLoop.main.perform(inModes: [.default, .modalPanel]) {
            MainActor.assumeIsolated { NSApp.reply(toApplicationShouldTerminate: true) }
        }
        CFRunLoopWakeUp(CFRunLoopGetMain())
    }
}
