#if DEBUG
import AppKit
import SwiftUI

/// Sets up one `ScreenshotScene` in the running app, captures it to `<output>/<scene>.png` and quits.
@MainActor
struct ScreenshotDirector {
    let scene: ScreenshotScene
    let output: URL
    let environment: AppEnvironment
    let openSettings: () -> Void
    private var data: ScreenshotSampleData { ScreenshotMode.sampleData }

    func run() async {
        // Never leave a stray instance behind if a step hangs.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(30))
            finish(error: "timed out")
        }
        NSApp.appearance = NSAppearance(named: .aqua)
        environment.requestedTimelineDay = data.showcaseDay
        environment.requestedSidebarItem = scene.sidebarItem
        guard let main = NSApp.windows.first(where: { $0.isVisible && $0.styleMask.contains(.titled) }) else {
            return finish(error: "no main window")
        }
        // The pointer may rest anywhere on screen; hover cards and highlights must not end up in the picture.
        main.ignoresMouseEvents = true
        // The pointer may rest anywhere on screen; hover cards and highlights must not end up in the picture.
        main.ignoresMouseEvents = true
        main.setContentSize(scene.windowSize)
        main.center()
        NSApp.activate()
        main.makeKeyAndOrderFront(nil)
        await pause(1.5)

        let windows: [NSWindow]
        switch scene {
        case .entryForm: windows = await openForm(in: main)
        case .settings: windows = await openSettingsWindow(over: main)
        case .menuBar: windows = await openPanel(hiding: main)
        case .timeline, .projects, .overview, .trackedApps: windows = [main]
        }
        // No focus ring on the first button (the panel already did this before choosing its day).
        if scene != .menuBar { windows.forEach { $0.makeFirstResponder(nil) } }
        await pause(1.5)
        guard let image = WindowSnapshot.combined(windows) else { return finish(error: "capture failed") }
        do {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            try WindowSnapshot.writePNG(image, to: output.appendingPathComponent("\(scene.rawValue).png"))
            finish(error: nil)
        } catch {
            finish(error: error.localizedDescription)
        }
    }

    private func openForm(in main: NSWindow) async -> [NSWindow] {
        ScreenshotFormRequest.shared.request = .init(range: data.unloggedRange, title: "Rest timer settings",
                                                            projectId: ScreenshotSampleData.ProjectID.fitness)
        await pause(1.5)
        return [main] + (main.attachedSheet.map { [$0] } ?? [])
    }

    /// The Settings window over the lower right of the main window, the way it opens on a real desktop.
    private func openSettingsWindow(over main: NSWindow) async -> [NSWindow] {
        openSettings()
        await pause(1.5)
        guard let settings = NSApp.windows.first(where: { $0 !== main && $0.isVisible && $0.styleMask.contains(.titled) }) else {
            return [main]
        }
        settings.ignoresMouseEvents = true
        // Fit the window to its form (it opens taller than needed); skip a fitting size that isn't laid out yet.
        if let fitting = settings.contentView?.fittingSize, fitting.height > 200 { settings.setContentSize(fitting) }
        settings.ignoresMouseEvents = true
        settings.setFrameOrigin(NSPoint(x: main.frame.maxX - settings.frame.width - 60, y: main.frame.minY + 60))
        settings.makeKeyAndOrderFront(nil)
        return [main, settings]
    }

    /// The panel content on the showcase day, with Xcode as the app being tracked right now.
    private func openPanel(hiding main: NSWindow) async -> [NSWindow] {
        let viewModel = MenuBarViewModel.make(environment: environment)
        let panel = ScreenshotPanelWindow(content: MenuBarContentView(environment: environment, viewModel: viewModel)
            .environment(environment))
        panel.ignoresMouseEvents = true
        panel.ignoresMouseEvents = true
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        main.orderOut(nil)
        await environment.tracker.handle(.trackedAppsChanged(Set(data.trackedApps.map(\.bundleIdentifier))))
        await environment.tracker.handle(.appActivated(ForegroundApp(bundleIdentifier: "com.apple.dt.Xcode", name: "Xcode")))
        panel.makeFirstResponder(nil)
        await pause(1)
        // Opening the panel jumped to today; every later key/visibility change would do that again.
        viewModel.timeline.go(to: data.showcaseDay)
        return [panel]
    }

    private func pause(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    private func finish(error: String?) {
        if let error { FileHandle.standardError.write(Data("Screenshot \(scene.rawValue) failed: \(error)\n".utf8)) }
        NSApp.terminate(nil)
    }
}
#endif
