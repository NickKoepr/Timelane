import Foundation

/// The links shown in About (Mac About panel, iOS Settings).
enum AboutLinks {
    static let all: [(title: String, url: URL)] = [
        ("Website", URL(string: "https://timelane.nickkoepr.nl")!),
        ("GitHub", URL(string: "https://github.com/NickKoepr/Timelane")!),
        ("Report an issue", URL(string: "https://github.com/NickKoepr/Timelane/issues")!),
    ]
}
