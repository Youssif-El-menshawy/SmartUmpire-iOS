//
//  XLSXMatchReportWriter.swift
//  SmartUmpire
//
//  Created by Youssef on 11/02/2026.
//

import Foundation
import ZIPFoundation

// MARK: - Public API

struct XLSXMatchReportWriter {

    struct Meta {
        let tournamentName: String
        let court: String
        let round: String
        let umpireName: String
        let player1: String
        let player2: String
        let status: String
        let time: String
        let finalScore: String?     // nil if not completed
        let generatedAt: Date
    }

    struct LogEvent {
        let time: Date
        let type: String
        let description: String
    }

    /// Generates a styled, print-optimized XLSX match report and returns a file URL in tmp.
    static func writeReport(meta: Meta, events: [LogEvent]) throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
        let folder = tmp.appendingPathComponent("xlsx_report_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        // 1) Write all XLSX part files into folder structure
        try writeCoreParts(into: folder, meta: meta, events: events)

        // 2) Zip into .xlsx
        let outURL = tmp.appendingPathComponent("SmartUmpire_Match_Report.xlsx")
        if FileManager.default.fileExists(atPath: outURL.path) {
            try FileManager.default.removeItem(at: outURL)
        }

        guard let archive = Archive(url: outURL, accessMode: .create) else {
            throw NSError(domain: "XLSXWriter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create zip archive"])
        }

        // zip entire folder contents preserving paths
        let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)!
        for case let fileURL as URL in enumerator {
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir)
            if isDir.boolValue { continue }

            let relPath = fileURL.path.replacingOccurrences(of: folder.path + "/", with: "")
            try archive.addEntry(
                with: relPath,
                fileURL: fileURL,
                compressionMethod: .deflate
            )
        }

        // Cleanup staging folder (optional)
        try? FileManager.default.removeItem(at: folder)
        return outURL
    }
}

// MARK: - Parts Writer

private extension XLSXMatchReportWriter {

    static func writeCoreParts(into root: URL, meta: Meta, events: [LogEvent]) throws {
        // Create folders
        try mkdir(root, "_rels")
        try mkdir(root, "xl")
        try mkdir(root, "xl/_rels")
        try mkdir(root, "xl/worksheets")

        // [Content_Types].xml
        try write(root.appendingPathComponent("[Content_Types].xml"), contentTypesXML())

        // _rels/.rels
        try write(root.appendingPathComponent("_rels/.rels"), relsXML())

        // xl/workbook.xml
        let printTitleRow = headerRowForPrinting(meta: meta)
        try write(root.appendingPathComponent("xl/workbook.xml"), workbookXML(printTitleRow: printTitleRow))

        // xl/_rels/workbook.xml.rels
        try write(root.appendingPathComponent("xl/_rels/workbook.xml.rels"), workbookRelsXML())

        // xl/styles.xml (this is where the “openpyxl-like” styling lives)
        try write(root.appendingPathComponent("xl/styles.xml"), stylesXML())

        // xl/worksheets/sheet1.xml (the actual sheet content + merges + print setup)
        let sheet = sheet1XML(meta: meta, events: events)
        try write(root.appendingPathComponent("xl/worksheets/sheet1.xml"), sheet)
    }

    static func mkdir(_ root: URL, _ path: String) throws {
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent(path, isDirectory: true),
            withIntermediateDirectories: true
        )
    }

    static func write(_ url: URL, _ xml: String) throws {
        try xml.data(using: .utf8)!.write(to: url, options: .atomic)
    }
}

// MARK: - XML Builders (Minimal XLSX Package)

private extension XLSXMatchReportWriter {

    // XLSX Content types
    static func contentTypesXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
          <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
          <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
        </Types>
        """
    }

    // Root rels points to workbook
    static func relsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1"
            Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"
            Target="xl/workbook.xml"/>
        </Relationships>
        """
    }

    static func workbookXML(printTitleRow: Int) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
          xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">

          <sheets>
            <sheet name="Match Report" sheetId="1" r:id="rId1"/>
          </sheets>

          <definedNames>
            <definedName name="_xlnm.Print_Titles" localSheetId="0">'Match Report'!$\(printTitleRow):$\(printTitleRow)</definedName>
          </definedNames>

        </workbook>
        """
    }


    static func workbookRelsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1"
            Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet"
            Target="worksheets/sheet1.xml"/>
          <Relationship Id="rId2"
            Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles"
            Target="styles.xml"/>
        </Relationships>
        """
    }

    /// Styles:
    /// - s=1: Big blue header (white, 20pt, bold, centered)
    /// - s=2: Section title (14pt bold)
    /// - s=3: Metadata label (bold)
    /// - s=4: Table header (gray fill, bold, centered, border)
    /// - s=5: Table cell centered + border
    /// - s=6: Table cell left + border
    static func stylesXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <fonts count="4">
            <font><sz val="11"/><name val="Calibri"/></font>
            <font><sz val="20"/><color rgb="FFFFFFFF"/><b/><name val="Calibri"/></font>
            <font><sz val="14"/><b/><name val="Calibri"/></font>
            <font><sz val="12"/><b/><name val="Calibri"/></font>
          </fonts>

          <fills count="3">
            <fill><patternFill patternType="none"/></fill>
            <fill><patternFill patternType="gray125"/></fill>
            <fill><patternFill patternType="solid"><fgColor rgb="FF2563EB"/><bgColor indexed="64"/></patternFill></fill>
          </fills>

          <borders count="2">
            <border>
              <left/><right/><top/><bottom/><diagonal/>
            </border>
            <border>
              <left style="thin"/><right style="thin"/><top style="thin"/><bottom style="thin"/><diagonal/>
            </border>
          </borders>

          <cellStyleXfs count="1">
            <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
          </cellStyleXfs>

          <cellXfs count="7">
            <!-- 0 default -->
            <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>

            <!-- 1 blue header -->
            <xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1">
              <alignment horizontal="center" vertical="center"/>
            </xf>

            <!-- 2 section title -->
            <xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1">
              <alignment horizontal="left" vertical="center"/>
            </xf>

            <!-- 3 metadata label bold -->
            <xf numFmtId="0" fontId="3" fillId="0" borderId="0" xfId="0" applyFont="1">
              <alignment horizontal="left" vertical="center"/>
            </xf>

            <!-- 4 table header -->
            <xf numFmtId="0" fontId="3" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1">
              <alignment horizontal="center" vertical="center"/>
            </xf>

            <!-- 5 table cell centered + border -->
            <xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1">
              <alignment horizontal="center" vertical="center" wrapText="1"/>
            </xf>

            <!-- 6 table cell left + border -->
            <xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1">
              <alignment horizontal="left" vertical="center" wrapText="1"/>
            </xf>
          </cellXfs>
        </styleSheet>
        """
    }

    static func headerRowForPrinting(meta: Meta) -> Int {
        // Rows:
        // 1 header
        // 2 generated
        // 3 spacer
        // 4 "Match Information"
        // metadata starts at 5
        let baseMetaCount = 8 // Tournament, Court, Round, Umpire, Player1, Player2, Status, Time
        let finalScoreCount = (meta.finalScore == nil ? 0 : 1)
        let metaRows = baseMetaCount + finalScoreCount

        // after metadata:
        // spacer row + "Event Log" row + table header row
        // Table header row index:
        // 4 (section) + metaRows (rows 5.. ) + 1 spacer + 1 eventLogTitle + 1 headerRow
        // BUT easiest: start from row 5:
        let lastMetaRow = 4 + metaRows
        let spacerRow = lastMetaRow + 1
        let eventLogTitleRow = spacerRow + 1
        let tableHeaderRow = eventLogTitleRow + 1

        return tableHeaderRow
    }

    
    static func sheet1XML(meta: Meta, events: [LogEvent]) -> String {
        // Helpers
        func esc(_ s: String) -> String {
            s
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;")
        }

        func cellInline(_ ref: String, _ s: Int, _ value: String) -> String {
            """
            <c r="\(ref)" s="\(s)" t="inlineStr"><is><t>\(esc(value))</t></is></c>
            """
        }

        // Layout matches your Python version:
        // A1:C1 merged blue header
        // A2:C2 merged generated timestamp
        // A4 section title
        // A5.. metadata rows
        // Event Log title, then headers row, then events
        // Freeze at A14 (same feel as your openpyxl mock)
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"

        var rows: [String] = []

        // Row 1 (header, merged)
        rows.append("""
        <row r="1" ht="28" customHeight="1">
          \(cellInline("A1", 1, "SmartUmpire Official Match Report"))
        </row>
        """)

        // Row 2 (generated, merged)
        rows.append("""
        <row r="2" ht="18" customHeight="1">
          \(cellInline("A2", 0, "Generated on \(df.string(from: meta.generatedAt))"))
        </row>
        """)

        // Row 3 spacer
        rows.append(#"<row r="3"/>"#)

        // Row 4 section title
        rows.append("""
        <row r="4">
          \(cellInline("A4", 2, "Match Information"))
        </row>
        """)

        // Metadata (row 5..)
        var r = 5
        let metadataPairs: [(String, String)] = [
            ("Tournament", meta.tournamentName),
            ("Court", meta.court),
            ("Round", meta.round),
            ("Umpire", meta.umpireName),
            ("Player 1", meta.player1),
            ("Player 2", meta.player2),
            ("Status", meta.status),
            ("Time", meta.time),
        ] + (meta.finalScore.map { [("Final Score", $0)] } ?? [])

        for (k, v) in metadataPairs {
            rows.append("""
            <row r="\(r)">
              \(cellInline("A\(r)", 3, k))
              \(cellInline("B\(r)", 0, v))
            </row>
            """)
            r += 1
        }

        // Spacer
        rows.append(#"<row r="\#(r)"/>"#); r += 1

        // Event Log title
        rows.append("""
        <row r="\(r)">
          \(cellInline("A\(r)", 2, "Event Log"))
        </row>
        """)
        r += 1

        // Table headers
        rows.append("""
        <row r="\(r)" ht="20" customHeight="1">
          \(cellInline("A\(r)", 4, "Time"))
          \(cellInline("B\(r)", 4, "Event Type"))
          \(cellInline("C\(r)", 4, "Description"))
        </row>
        """)
        let headerRowForPrinting = r
        r += 1

        // Event rows
        let tf = DateFormatter()
        tf.dateFormat = "HH:mm"
        for ev in events {
            rows.append("""
            <row r="\(r)">
              \(cellInline("A\(r)", 5, tf.string(from: ev.time)))
              \(cellInline("B\(r)", 5, ev.type))
              \(cellInline("C\(r)", 6, ev.description))
            </row>
            """)
            r += 1
        }
        
        
        let lastRowNumber = r - 1
        let dimensionXML = """
        <dimension ref="A1:C\(lastRowNumber)"/>
        """


        // Columns width like your openpyxl: 12, 18, 60
        let colsXML = """
        <cols>
          <col min="1" max="1" width="12" customWidth="1"/>
          <col min="2" max="2" width="18" customWidth="1"/>
          <col min="3" max="3" width="60" customWidth="1"/>
        </cols>
        """

        // Merges: A1:C1 and A2:C2
        let mergeXML = """
        <mergeCells count="2">
          <mergeCell ref="A1:C1"/>
          <mergeCell ref="A2:C2"/>
        </mergeCells>
        """

        // Freeze panes at A14 (same as your python file)
        // (Excel requires sheetViews with pane + selection)
        let freezeRow = headerRowForPrinting + 1   // first event row
        let freezeSplit = max(0, freezeRow - 1)

        let sheetViews = """
        <sheetViews>
          <sheetView workbookViewId="0">
            <pane ySplit="\(freezeSplit)" topLeftCell="A\(freezeRow)" activePane="bottomLeft" state="frozen"/>
            <selection pane="bottomLeft" activeCell="A\(freezeRow)" sqref="A\(freezeRow)"/>
          </sheetView>
        </sheetViews>
        """


        // PRINT-OPTIMIZED:
        // - Fit to width (1 page wide), unlimited height
        // - Reasonable margins
        // - Repeat the table header row on each printed page
        // - Paper size: 9 = A4 (use 1 = Letter if you prefer)

        // NOTE: definedNames must live in workbook.xml for strict spec,
        // but Excel still opens when placed here in many cases.
        // If you want spec-perfect, I’ll move definedNames into workbook.xml and add calcChain exclusions.

        let sheetPr = """
        <sheetPr>
          <pageSetUpPr fitToPage="1"/>
        </sheetPr>
        """

        let pageMargins = """
        <pageMargins left="0.5" right="0.5" top="0.75" bottom="0.75" header="0.3" footer="0.3"/>
        """

        let pageSetup = """
        <pageSetup paperSize="9" orientation="portrait" fitToWidth="1" fitToHeight="0"/>
        """


        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
          xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">

          \(sheetPr)
          \(dimensionXML)
          \(sheetViews)
          \(colsXML)

          <sheetData>
            \(rows.joined(separator: "\n"))
          </sheetData>

          \(mergeXML)
          \(pageMargins)
          \(pageSetup)

        </worksheet>
        """
    }
}
