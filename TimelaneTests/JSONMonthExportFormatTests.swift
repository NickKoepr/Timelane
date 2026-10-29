import Foundation
import Testing
@testable import Timelane

struct JSONMonthExportFormatTests {
    func decode() throws -> [String: Any] {
        let data = try JSONMonthExportFormat().data(for: MonthExportFixtures.sample())
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func header() throws {
        let json = try decode()
        #expect(json["schemaVersion"] as? Int == 1)
        #expect(json["app"] as? String == "Timelane")
        #expect(json["month"] as? String == "2026-10")
        #expect(json["timeZone"] as? String == "Europe/Amsterdam")
        #expect(json["generatedAt"] as? String == "2026-10-29T14:03:00+01:00")
        #expect(json["totalMinutes"] as? Int == 350)
        #expect(json["total"] as? String == "5:50")
    }

    @Test func entriesHaveOffsetsAndNulls() throws {
        let json = try decode()
        let entries = try #require(json["entries"] as? [[String: Any]])
        #expect(entries.count == 3)
        #expect(entries[0]["start"] as? String == "2026-10-03T09:00:00+02:00")
        #expect(entries[0]["date"] as? String == "2026-10-03")
        #expect(entries[0]["durationMinutes"] as? Int == 210)
        #expect(entries[0]["duration"] as? String == "3:30")
        #expect(entries[0]["title"] as? String == "A & B <c>")
        #expect(entries[0]["note"] is NSNull)
        #expect(entries[1]["start"] as? String == "2026-10-24T09:00:00+02:00")
        #expect(entries[1]["durationMinutes"] as? Int == 80)
        #expect(entries[1]["duration"] as? String == "1:20")
        #expect(entries[2]["start"] as? String == "2026-10-26T09:00:00+01:00")
        let projects = try #require(json["projects"] as? [[String: Any]])
        #expect(projects[1]["archived"] as? Bool == true)
    }

    @Test func isPrettyPrinted() throws {
        let data = try JSONMonthExportFormat().data(for: MonthExportFixtures.sample())
        #expect(String(decoding: data, as: UTF8.self).contains("\n  \"app\""))
    }
}
