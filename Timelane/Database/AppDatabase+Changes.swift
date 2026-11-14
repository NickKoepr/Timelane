import GRDB

extension AppDatabase {
    /// Emits once after every committed write to one of `tables` (any table when nil). Keeps GRDB out of the backup service.
    func changes(tables: [String]? = nil) -> AsyncStream<Void> {
        let observation = tables.map { names in DatabaseRegionObservation(tracking: names.map { Table($0) }) }
            ?? DatabaseRegionObservation(tracking: DatabaseRegion.fullDatabase)
        let writer = self.writer
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let cancellable = observation.start(
                in: writer,
                onError: { _ in continuation.finish() },
                onChange: { _ in continuation.yield() })
            continuation.onTermination = { _ in cancellable.cancel() }
        }
    }
}
