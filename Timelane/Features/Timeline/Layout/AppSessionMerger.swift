import Foundation

/// Cleans up fragmented raw sessions for display. The stored data is never changed.
enum AppSessionMerger {
    static let mergeGap = TrackingSettings.mergeGap
    static let minimumDuration = TrackingSettings.minimumBlockDuration

    static func blocks(from sessions: [AppSession], in range: DateRange, now: Date) -> [AppSessionBlockModel] {
        let clipped = sessions.compactMap { session -> AppSessionBlockModel? in
            let end = session.end ?? now
            guard end > session.start,
                  let part = DateRange(start: session.start, end: end).intersection(with: range) else { return nil }
            return AppSessionBlockModel(bundleIdentifier: session.bundleIdentifier, appName: session.appName,
                                        start: part.start, end: part.end)
        }
        .sorted { $0.start < $1.start }

        let merged = merge(clipped)
        let longEnough = merged.filter { $0.duration >= minimumDuration }
        // Dropping short blocks can leave same-app neighbours that are now close together.
        return merge(longEnough)
    }

    private static func merge(_ blocks: [AppSessionBlockModel]) -> [AppSessionBlockModel] {
        var result: [AppSessionBlockModel] = []
        for block in blocks {
            if let last = result.last,
               last.bundleIdentifier == block.bundleIdentifier,
               block.start.timeIntervalSince(last.end) < mergeGap {
                result[result.count - 1] = AppSessionBlockModel(
                    bundleIdentifier: last.bundleIdentifier, appName: last.appName,
                    start: last.start, end: max(last.end, block.end))
            } else {
                result.append(block)
            }
        }
        return result
    }
}
