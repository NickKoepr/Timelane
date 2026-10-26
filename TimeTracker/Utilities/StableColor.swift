import SwiftUI

/// Deterministic color per string (Swift's `hashValue` changes between launches).
enum StableColor {
    static func color(for key: String) -> Color {
        var hash: UInt64 = 14_695_981_039_346_656_037        // FNV-1a
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return Color(hue: Double(hash % 360) / 360, saturation: 0.55, brightness: 0.85)
    }
}
