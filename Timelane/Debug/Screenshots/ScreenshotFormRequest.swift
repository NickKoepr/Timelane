#if DEBUG
import Foundation

/// Lets the screenshot director open the main window's new-entry form (the form lives in `TimelineScreen`).
@MainActor @Observable
final class ScreenshotFormRequest {
    static let shared = ScreenshotFormRequest()

    struct Request: Equatable {
        let range: DateRange
        let title: String
        let projectId: Int64
    }

    var request: Request?
}
#endif
