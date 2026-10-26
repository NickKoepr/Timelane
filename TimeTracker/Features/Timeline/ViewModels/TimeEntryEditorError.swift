import Foundation

enum TimeEntryEditorError: LocalizedError {
    case tooShort

    var errorDescription: String? {
        switch self {
        case .tooShort: "A time entry must be at least a minute long."
        }
    }
}
