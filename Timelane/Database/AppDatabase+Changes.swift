import GRDB

extension AppDatabase {
    /// Emits once after every committed write to any table. Keeps GRDB out of the backup service.
    func changes() -> AsyncStream<Void> {
        let observation = DatabaseRegionObservation(tracking: DatabaseRegion.fullDatabase)
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
