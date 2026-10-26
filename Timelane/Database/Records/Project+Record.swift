import GRDB

extension Project: FetchableRecord, MutablePersistableRecord {
    static func databaseDateDecodingStrategy(for column: String) -> DatabaseDateDecodingStrategy { .timeIntervalSince1970 }
    static func databaseDateEncodingStrategy(for column: String) -> DatabaseDateEncodingStrategy { .timeIntervalSince1970 }

    mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}

extension ProjectMonthTotal: FetchableRecord {
    init(row: Row) throws {
        project = try Project(row: row)
        totalSeconds = row["totalSeconds"]
    }
}
