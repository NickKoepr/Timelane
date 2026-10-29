import Foundation
import Testing
@testable import Timelane

struct XLSXWriterTests {
    func parts() throws -> [(path: String, data: Data)] {
        try ZipTestReader.read(ExcelMonthExportFormat().data(for: MonthExportFixtures.sample()))
    }

    @Test func containsRequiredParts() throws {
        let files = try parts()
        for path in ["[Content_Types].xml", "_rels/.rels", "xl/workbook.xml", "xl/_rels/workbook.xml.rels",
                     "xl/styles.xml", "xl/worksheets/sheet1.xml", "xl/worksheets/sheet2.xml"] {
            #expect(files.contains { $0.path == path }, "\(path)")
        }
        let types = try #require(ZipTestReader.string(files, "[Content_Types].xml"))
        #expect(types.contains("/xl/worksheets/sheet1.xml") && types.contains("/xl/worksheets/sheet2.xml"))
        let workbook = try #require(ZipTestReader.string(files, "xl/workbook.xml"))
        #expect(workbook.contains("name=\"Summary\"") && workbook.contains("name=\"Entries\""))
    }

    @Test func sheetContents() throws {
        let files = try parts()
        let summary = try #require(ZipTestReader.string(files, "xl/worksheets/sheet1.xml"))
        #expect(summary.contains("Project") && summary.contains("Archived") && summary.contains("Total"))
        #expect(summary.contains("Acme &amp; Co"))
        // Total row: 21000 s = 5.8333… h, same as the export total.
        #expect(summary.contains("<v>\(21_000.0 / 3600)</v>"))
        let entries = try #require(ZipTestReader.string(files, "xl/worksheets/sheet2.xml"))
        for header in ["Date", "Start", "End", "Hours", "Project", "Title", "Note"] { #expect(entries.contains(">\(header)<")) }
        #expect(entries.contains("A &amp; B &lt;c&gt;"))
        #expect(entries.contains("state=\"frozen\""))
    }

    @Test func allPartsAreWellFormedXML() throws {
        for file in try parts() {
            let parser = XMLParser(data: file.data)
            #expect(parser.parse(), "\(file.path): \(parser.parserError?.localizedDescription ?? "")")
        }
    }

    @Test func helpers() {
        #expect(XLSXWriter.columnName(0) == "A")
        #expect(XLSXWriter.columnName(25) == "Z")
        #expect(XLSXWriter.columnName(26) == "AA")
        #expect(XLSXWriter.columnName(701) == "ZZ")
        #expect(XLSXWriter.columnName(702) == "AAA")
        let serial = XLSXWriter.serial(for: MonthExportFixtures.date(2026, 10, 3, 9), timeZone: MonthExportFixtures.cal.timeZone)
        #expect(abs(serial - 46_298.375) < 1e-9)
        #expect(XLSXWriter.escape("a\u{0}b\u{1}c") == "abc")
        #expect(XLSXWriter.sanitizedSheetName("a/b:c" + String(repeating: "x", count: 40)).count == 31)
    }

    @Test func emptyMonthStillWrites() throws {
        let empty = MonthExport(month: MonthExportFixtures.october, generatedAt: .now,
                                timeZone: MonthExportFixtures.cal.timeZone, projects: [], entries: [])
        let files = try ZipTestReader.read(ExcelMonthExportFormat().data(for: empty))
        let summary = try #require(ZipTestReader.string(files, "xl/worksheets/sheet1.xml"))
        #expect(summary.contains("No hours registered in"))
    }
}
