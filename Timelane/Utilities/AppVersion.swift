import Foundation

/// "1.9 (12)": the marketing version with the build number, as shown in About.
enum AppVersion {
    static func display(short: String?, build: String?) -> String {
        switch (short, build) {
        case let (short?, build?): "\(short) (\(build))"
        case let (short?, nil): short
        case let (nil, build?): "(\(build))"
        case (nil, nil): "–"
        }
    }

    static var current: String {
        let info = Bundle.main.infoDictionary
        return display(short: info?["CFBundleShortVersionString"] as? String, build: info?["CFBundleVersion"] as? String)
    }
}
