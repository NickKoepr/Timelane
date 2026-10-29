import Foundation

/// The fixed XML parts of an .xlsx package.
enum XLSXParts {
    static let header = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
    static let mainNamespace = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
    private static let relNamespace = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    private static let packageRelNamespace = "http://schemas.openxmlformats.org/package/2006/relationships"

    // Cell style indexes in `styles`: plain styles 0...3, the same in bold at +4.
    static let generalStyle = 0
    static let dateStyle = 1
    static let timeStyle = 2
    static let hoursStyle = 3
    static let boldOffset = 4

    static func contentTypes(sheetCount: Int) -> String {
        let sheets = (1...max(sheetCount, 1)).map {
            "<Override PartName=\"/xl/worksheets/sheet\($0).xml\" "
                + "ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>"
        }.joined()
        return header + "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">"
            + "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>"
            + "<Default Extension=\"xml\" ContentType=\"application/xml\"/>"
            + "<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>"
            + "<Override PartName=\"/xl/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml\"/>"
            + sheets + "</Types>"
    }

    static let rootRelationships = header + "<Relationships xmlns=\"\(packageRelNamespace)\">"
        + "<Relationship Id=\"rId1\" Type=\"\(relNamespace)/officeDocument\" Target=\"xl/workbook.xml\"/></Relationships>"

    static func workbook(sheetNames: [String]) -> String {
        let sheets = sheetNames.enumerated().map {
            "<sheet name=\"\(XLSXWriter.escape($1))\" sheetId=\"\($0 + 1)\" r:id=\"rId\($0 + 1)\"/>"
        }.joined()
        return header + "<workbook xmlns=\"\(mainNamespace)\" xmlns:r=\"\(relNamespace)\"><sheets>\(sheets)</sheets></workbook>"
    }

    static func workbookRelationships(sheetCount: Int) -> String {
        let sheets = (1...max(sheetCount, 1)).map {
            "<Relationship Id=\"rId\($0)\" Type=\"\(relNamespace)/worksheet\" Target=\"worksheets/sheet\($0).xml\"/>"
        }.joined()
        let styles = "<Relationship Id=\"rId\(sheetCount + 1)\" Type=\"\(relNamespace)/styles\" Target=\"styles.xml\"/>"
        return header + "<Relationships xmlns=\"\(packageRelNamespace)\">\(sheets)\(styles)</Relationships>"
    }

    /// Number formats: 164 = yyyy-mm-dd, 165 = hh:mm, 166 = 0.00. Fonts: 0 regular, 1 bold.
    static let styles: String = {
        let formats = [0, 164, 165, 166]
        let xfs = (0..<2).flatMap { bold in
            formats.map { format in
                "<xf numFmtId=\"\(format)\" fontId=\"\(bold)\" fillId=\"0\" borderId=\"0\" xfId=\"0\""
                    + (format != 0 ? " applyNumberFormat=\"1\"" : "") + (bold == 1 ? " applyFont=\"1\"" : "") + "/>"
            }
        }.joined()
        return header + "<styleSheet xmlns=\"\(mainNamespace)\">"
            + "<numFmts count=\"3\"><numFmt numFmtId=\"164\" formatCode=\"yyyy\\-mm\\-dd\"/>"
            + "<numFmt numFmtId=\"165\" formatCode=\"hh:mm\"/><numFmt numFmtId=\"166\" formatCode=\"0.00\"/></numFmts>"
            + "<fonts count=\"2\"><font><sz val=\"12\"/><name val=\"Calibri\"/></font>"
            + "<font><b/><sz val=\"12\"/><name val=\"Calibri\"/></font></fonts>"
            + "<fills count=\"2\"><fill><patternFill patternType=\"none\"/></fill><fill><patternFill patternType=\"gray125\"/></fill></fills>"
            + "<borders count=\"1\"><border><left/><right/><top/><bottom/><diagonal/></border></borders>"
            + "<cellStyleXfs count=\"1\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/></cellStyleXfs>"
            + "<cellXfs count=\"8\">\(xfs)</cellXfs>"
            + "<cellStyles count=\"1\"><cellStyle name=\"Normal\" xfId=\"0\" builtinId=\"0\"/></cellStyles></styleSheet>"
    }()
}
