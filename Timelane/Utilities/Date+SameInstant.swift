import Foundation

extension Date {
    /// Dates are stored as Unix `Double`; reading one back can differ by a few ULPs from the original.
    /// Compare stored dates with this instead of `==`.
    func isSameInstant(as other: Date, tolerance: TimeInterval = 0.001) -> Bool {
        abs(timeIntervalSince(other)) < tolerance
    }
}
