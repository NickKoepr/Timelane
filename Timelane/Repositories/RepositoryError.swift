import Foundation

enum RepositoryError: LocalizedError, Equatable {
    case duplicateName
    case duplicateCustomId
    case projectHasEntries
    case invalidRange

    var errorDescription: String? {
        switch self {
        case .duplicateName: "A project with this name already exists."
        case .duplicateCustomId: "Another project already uses this ID."
        case .projectHasEntries: "This project has registered time and cannot be deleted. Archive it instead."
        case .invalidRange: "The end time must be after the start time."
        }
    }
}
