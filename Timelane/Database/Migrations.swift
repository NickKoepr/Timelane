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

        migrator.registerMigration("v2") { db in
            try db.alter(table: "timeEntry") { t in t.add(column: "title", .text) }
            try db.create(table: "trackedApp") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("bundleIdentifier", .text).notNull().unique()
                t.column("name", .text).notNull()
                t.column("addedAt", .double).notNull()
            }
        }

        migrator.registerMigration("v3") { db in
            // A tracked app can be linked to a project (automatic logged hours).
            try db.alter(table: "trackedApp") { t in
                t.add(column: "projectId", .integer).references("project", onDelete: .setNull)
            }
        }

        return migrator
    }
}
