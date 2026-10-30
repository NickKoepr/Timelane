#if DEBUG
import Foundation

/// DEBUG-only mode in which the app shows sample data, captures one scene and quits.
/// Started with `-screenshotScene <scene> -screenshotOutput <dir>` (see `Tools/make-app-store-screenshots.sh`).
enum ScreenshotMode {
    static let scene: ScreenshotScene? = UserDefaults.standard.string(forKey: "screenshotScene").flatMap(ScreenshotScene.init)
    static let outputDirectory: URL? = UserDefaults.standard.string(forKey: "screenshotOutput")
        .map { URL(fileURLWithPath: $0, isDirectory: true) }

    /// One sample data set per run, shared by the database and the director (which needs the showcase day).
    static let sampleData = ScreenshotSampleData()

    static var isActive: Bool { scene != nil && outputDirectory != nil }

    /// Screenshot arguments were passed but are incomplete or unknown: the app must stop instead of
    /// falling back to the real database and tracking.
    static var isMisconfigured: Bool {
        let defaults = UserDefaults.standard
        let requested = defaults.object(forKey: "screenshotScene") != nil || defaults.object(forKey: "screenshotOutput") != nil
        return requested && !isActive
    }
}
#endif
