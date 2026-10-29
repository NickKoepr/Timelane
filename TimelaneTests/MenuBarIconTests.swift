import AppKit
import Foundation
import Testing
@testable import Timelane

@MainActor
struct MenuBarIconTests {
    final class Clock { var now = TestCalendar.date(2026, 11, 3, 9, 0) }

    @Test func styleMapping() {
        #expect(MenuBarIconStyle(isRecording: false) == .normal)
        #expect(MenuBarIconStyle(isRecording: true) == .recording)
        #expect(MenuBarIconStyle.normal.title == "Timelane")
        #expect(MenuBarIconStyle.recording.title == "Timelane – Recording")
    }

    @Test func rendererImages() {
        let normal = MenuBarIconRenderer.image(for: .normal)
        let rec = MenuBarIconRenderer.image(for: .recording)
        #expect(normal.isTemplate)
        #expect(!rec.isTemplate)
        #expect(normal.size == NSSize(width: 18, height: 18))
        #expect(rec.size == NSSize(width: 18, height: 18))
    }

    @Test func recordingImageHasRedDot() throws {
        let image = MenuBarIconRenderer.image(for: .recording)
        let rep = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 36, pixelsHigh: 36,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        rep.size = NSSize(width: 18, height: 18)  // 36 px = @2x
        let ctx = try #require(NSGraphicsContext(bitmapImageRep: rep))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        image.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
        NSGraphicsContext.restoreGraphicsState()
        // Dot centre (15, 3) pt; bitmap rows count from the top.
        let color = try #require(rep.colorAt(x: 30, y: 36 - 6)?.usingColorSpace(.deviceRGB))
        #expect(color.alphaComponent > 0.5)
        #expect(color.redComponent > 0.7)
        #expect(color.greenComponent < 0.5)
        #expect(color.blueComponent < 0.5)
    }

    @Test func styleFollowsTimer() {
        let clock = Clock()
        let timer = RecordingTimer(store: InMemoryRecordingTimerStore(), calendar: TestCalendar.make(), clock: { clock.now })
        #expect(MenuBarIconStyle(isRecording: timer.isRunning) == .normal)
        timer.start()
        #expect(MenuBarIconStyle(isRecording: timer.isRunning) == .recording)
        _ = timer.stop()
        #expect(MenuBarIconStyle(isRecording: timer.isRunning) == .normal)
    }
}
