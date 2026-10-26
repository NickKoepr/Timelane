import GRDB

extension TrackedApp: FetchableRecord, MutablePersistableRecord {
    static func databaseDateDecodingStrategy(for column: String) -> DatabaseDateDecodingStrategy { .timeIntervalSince1970 }
    static func databaseDateEncodingStrategy(for column: String) -> DatabaseDateEncodingStrategy { .timeIntervalSince1970 }

    mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}
