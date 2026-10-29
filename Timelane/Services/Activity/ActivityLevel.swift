import Foundation

/// The five brightness steps of a heatmap square (GitHub-style).
enum ActivityLevel: Int, CaseIterable, Sendable {
    case none, low, medium, high, max

    /// Fixed hour thresholds, so colors mean the same in every year:
    /// 0 → none, (0, 2h) → low, [2h, 4h) → medium, [4h, 6h) → high, ≥ 6h → max.
    init(seconds: TimeInterval) {
        switch seconds {
        case ..<1: self = .none   // sub-second noise (Double round-trip) counts as nothing
        case ..<(2 * 3600): self = .low
        case ..<(4 * 3600): self = .medium
        case ..<(6 * 3600): self = .high
        default: self = .max
        }
    }
}
