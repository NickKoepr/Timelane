import SwiftUI

enum ProjectColor {
    static let palette: [String] = [
        "#4F8EF7", "#34C759", "#FF9500", "#FF3B30", "#AF52DE",
        "#5AC8FA", "#FFCC00", "#FF2D55", "#8E8E93", "#30B0C7",
    ]

    /// Next palette color, cycling by the number of projects that already exist.
    static func hex(forIndex index: Int) -> String { palette[index % palette.count] }

    static func color(hex: String) -> Color {
        var value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if value.count != 6 { value = "8E8E93" }
        let number = UInt32(value, radix: 16) ?? 0x8E8E93
        return Color(
            red: Double((number >> 16) & 0xFF) / 255,
            green: Double((number >> 8) & 0xFF) / 255,
            blue: Double(number & 0xFF) / 255
        )
    }
}

extension Project {
    var color: Color { ProjectColor.color(hex: colorHex) }
}
