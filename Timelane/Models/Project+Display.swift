import Foundation

extension Project {
    /// Plain-text name including the custom ID, for menus, pickers and accessibility labels.
    var titleWithCustomId: String { customId.map { "\(name) (\($0))" } ?? name }

    /// Like `titleWithCustomId`, with a long ID shortened (menus and pickers outside the Projects screen).
    var shortTitleWithCustomId: String {
        customId.map { "\(name) (\(ProjectCustomId.shortened($0)))" } ?? name
    }
}
