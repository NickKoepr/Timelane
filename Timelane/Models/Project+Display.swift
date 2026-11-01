import Foundation

extension Project {
    /// Plain-text name including the custom ID, for menus, pickers and accessibility labels.
    var titleWithCustomId: String { customId.map { "\(name) (\($0))" } ?? name }
}
