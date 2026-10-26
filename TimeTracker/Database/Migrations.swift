import GRDB

enum Migrations {
    /// Every schema change is a NEW migration; never edit an existing one.
    static func makeMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            // Dates are stored as Unix timestamps (REAL) so range math in SQL is plain arithmetic.
            try db.create(table: "project") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull().unique().collate(.nocase)
                t.column("colorHex", .text).notNull()
                t.column("isArchived", .boolean).notNull().defaults(to: false)
                t.column("createdAt", .double).notNull()
            }

            try db.create(table: "timeEntry") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("projectId", .integer).notNull().references("project", onDelete: .restrict)
                t.column("start", .double).notNull()
                t.column("end", .double).notNull()
                t.column("note", .text)
                t.column("createdAt", .double).notNull()
                t.column("updatedAt", .double).notNull()
                t.check(sql: "\"end\" > start")
            }
            try db.create(index: "timeEntry_start", on: "timeEntry", columns: ["start"])
            try db.create(index: "timeEntry_projectId", on: "timeEntry", columns: ["projectId"])

            try db.create(table: "appSession") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("bundleIdentifier", .text).notNull()
                t.column("appName", .text).notNull()
                t.column("start", .double).notNull()
                t.column("end", .double)
            }
            try db.create(index: "appSession_start", on: "appSession", columns: ["start"])
        }

        return migrator
    }
}
