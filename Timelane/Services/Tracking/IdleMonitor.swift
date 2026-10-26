import CoreGraphics
import Foundation

/// Polls the system idle time and emits pause/resume events.
@MainActor
final class IdleMonitor {
    private var detector = IdleDetector()
    private var task: Task<Void, Never>?
    private let sink: @Sendable (ActivityEvent) -> Void

    init(sink: @escaping @Sendable (ActivityEvent) -> Void) {
        self.sink = sink
    }

    func start() {
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(TrackingSettings.idleCheckInterval))
                self?.check()
            }
        }
    }

    func stop() { task?.cancel() }

    private func check() {
        let anyInput = CGEventType(rawValue: ~0)!   // kCGAnyInputEventType
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
        if let event = detector.evaluate(idleSeconds: idle, now: .now) { sink(event) }
    }
}
