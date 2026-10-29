import Foundation

/// Writes a `SpreadsheetWorkbook` as an Office Open XML (.xlsx) file (a stored ZIP of XML parts).
enum XLSXWriter {
    static func data(for workbook: SpreadsheetWorkbook) throws -> Data {
        let sheets = workbook.sheets
        var files: [(path: String, data: Data)] = [
            ("[Content_Types].xml", part(XLSXParts.contentTypes(sheetCount: sheets.count))),
            ("_rels/.rels", part(XLSXParts.rootRelationships)),
            ("xl/workbook.xml", part(XLSXParts.workbook(sheetNames: sheets.map { sanitizedSheetName($0.name) }))),
            ("xl/_rels/workbook.xml.rels", part(XLSXParts.workbookRelationships(sheetCount: sheets.count))),
            ("xl/styles.xml", part(XLSXParts.styles)),
        ]
        for (index, sheet) in sheets.enumerated() {
            files.append(("xl/worksheets/sheet\(index + 1).xml", part(sheetXML(sheet, timeZone: workbook.timeZone))))
        }
        return try ZipArchiveWriter.archive(of: files)
    }

    // MARK: Helpers (internal for tests)

    /// Column letters for a zero-based index: 0 → A, 25 → Z, 26 → AA.
    static func columnName(_ index: Int) -> String {
        var number = index + 1
        var name = ""
        while number > 0 {
            let remainder = (number - 1) % 26
            name = String(UnicodeScalar(UInt8(65 + remainder))) + name
            number = (number - 1) / 26
        }
        return name
    }

    /// Days since 1899-12-30 in `timeZone` (fraction = time of day).
    static func serial(for date: Date, timeZone: TimeZone) -> Double {
        let local = date.timeIntervalSince1970 + Double(timeZone.secondsFromGMT(for: date))
        return local / 86_400 + 25_569
    }

    static func escape(_ text: String) -> String {
        var result = ""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            case "'": result += "&apos;"
            case "\t", "\n", "\r": result.unicodeScalars.append(scalar)
            default:
                let v = scalar.value
                let legal = (v >= 0x20 && v <= 0xD7FF) || (v >= 0xE000 && v <= 0xFFFD) || v >= 0x10000
                if legal { result.unicodeScalars.append(scalar) }
            }
        }
        return result
    }

    static func sanitizedSheetName(_ name: String) -> String {
        let cleaned = String(name.filter { !"[]:*?/\\".contains($0) }.prefix(31))
        return cleaned.isEmpty ? "Sheet" : cleaned
    }

    // MARK: Private

    private static func part(_ xml: String) -> Data { Data(xml.utf8) }

    private static func sheetXML(_ sheet: SpreadsheetWorkbook.Sheet, timeZone: TimeZone) -> String {
        var xml = XLSXParts.header + "<worksheet xmlns=\"\(XLSXParts.mainNamespace)\">"
        if sheet.frozenRows > 0 {
            xml += "<sheetViews><sheetView workbookViewId=\"0\"><pane ySplit=\"\(sheet.frozenRows)\" "
                + "topLeftCell=\"A\(sheet.frozenRows + 1)\" activePane=\"bottomLeft\" state=\"frozen\"/></sheetView></sheetViews>"
        }
        if !sheet.columnWidths.isEmpty {
            xml += "<cols>" + sheet.columnWidths.enumerated().map { index, width in
                "<col min=\"\(index + 1)\" max=\"\(index + 1)\" width=\"\(width)\" customWidth=\"1\"/>"
            }.joined() + "</cols>"
        }
        xml += "<sheetData>"
        for (rowIndex, row) in sheet.rows.enumerated() {
            let cells = row.cells.enumerated().compactMap {
                cellXML($1, reference: "\(columnName($0))\(rowIndex + 1)", bold: row.bold, timeZone: timeZone)
            }
            xml += "<row r=\"\(rowIndex + 1)\">" + cells.joined() + "</row>"
        }
        return xml + "</sheetData></worksheet>"
    }

    private static func cellXML(_ cell: SpreadsheetCell, reference: String, bold: Bool, timeZone: TimeZone) -> String? {
        let base = bold ? XLSXParts.boldOffset : 0
        switch cell {
        case .empty:
            return nil
        case .text(let text):
            let style = base + XLSXParts.generalStyle
            return "<c r=\"\(reference)\" s=\"\(style)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(escape(text))</t></is></c>"
        case .number(let value, let numberStyle):
            let style = base + (numberStyle == .hours ? XLSXParts.hoursStyle : XLSXParts.generalStyle)
            return "<c r=\"\(reference)\" s=\"\(style)\"><v>\(value)</v></c>"
        case .date(let date):
            let value = serial(for: date, timeZone: timeZone).rounded(.down)
            return "<c r=\"\(reference)\" s=\"\(base + XLSXParts.dateStyle)\"><v>\(Int(value))</v></c>"
        case .time(let date):
            let serial = serial(for: date, timeZone: timeZone)
            return "<c r=\"\(reference)\" s=\"\(base + XLSXParts.timeStyle)\"><v>\(serial - serial.rounded(.down))</v></c>"
        }
    }
}
