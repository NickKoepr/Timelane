import Foundation
import Testing
@testable import TimeTracker

struct TimeEntryRepositoryTests {
    let db: AppDatabase
    let entries: GRDBTimeEntryRepository
    let projectId: Int64
    let cal = TestCalendar.make()

    init() async throws {
        db = try AppDatabase.inMemory()
        entries = GRDBTimeEntryRepository(database: db)
        projectId = try await GRDBProjectRepository(database: db)
            .save(Project(name: "Alpha", colorHex: "#4F8EF7")).id!
    }

    func date(_ d: Int, _ h: Int, _ min: Int = 0) -> Date { TestCalendar.date(2026, 11, d, h, min, calendar: cal) }

    @Test func savesDeletesAndFetchesByRange() async throws {
        try await entries.save([
            TimeEntry(projectId: projectId, start: date(3, 9), end: date(3, 10)),
            TimeEntry(projectId: projectId, start: date(4, 9), end: date(4, 10)),
        ], deleting: [])
        let day3 = DateRange.day(of: date(3, 12), calendar: cal)
        var fetched = try await entries.entries(in: day3)
        #expect(fetched.count == 1)

        var edited = fetched[0]
        edited.end = date(3, 11)
        try await entries.save([edited], deleting: [])
        fetched = try await entries.entries(in: day3)
        #expect(fetched.count == 1)
        #expect(fetched[0].end == date(3, 11))

        try await entries.save([], deleting: [fetched[0].id!])
        #expect(try await entries.entries(in: day3).isEmpty)
    }

    @Test func entryCrossingMidnightAppearsOnBothDays() async throws {
        try await entries.save([TimeEntry(projectId: projectId, start: date(3, 23), end: date(4, 1))], deleting: [])
        #expect(try await entries.entries(in: .day(of: date(3, 12), calendar: cal)).count == 1)
        #expect(try await entries.entries(in: .day(of: date(4, 12), calendar: cal)).count == 1)
    }

    @Test func invalidRangeIsRejected() async throws {
        await #expect(throws: RepositoryError.invalidRange) {
            try await entries.save([TimeEntry(projectId: projectId, start: date(3, 10), end: date(3, 9))], deleting: [])
        }
    }

    @Test func observationEmitsCurrentValue() async throws {
        try await entries.save([TimeEntry(projectId: projectId, start: date(3, 9), end: date(3, 10))], deleting: [])
        var iterator = entries.observeEntries(in: .day(of: date(3, 12), calendar: cal)).makeAsyncIterator()
        #expect(await iterator.next()?.count == 1)
    }
}
