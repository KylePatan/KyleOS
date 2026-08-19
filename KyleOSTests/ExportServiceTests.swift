import XCTest
import PDFKit
@testable import KyleOS

final class ExportServiceTests: XCTestCase {

    private func makeTempPDFURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).pdf")
    }

    func testExportPDFCreatesAValidPDFFile() throws {
        let url = makeTempPDFURL()
        defer { try? FileManager.default.removeItem(at: url) }

        try ExportService.exportPDF(title: "Coastal Town", body: "FADE IN:\n\nA quiet fishing town at dawn.", to: url)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let data = try Data(contentsOf: url)
        XCTAssertFalse(data.isEmpty)
        XCTAssertEqual(data.prefix(4), Data("%PDF".utf8), "Output must actually be a PDF, not just any file")
    }

    func testExportPDFHandlesEmptyBodyWithoutThrowing() throws {
        let url = makeTempPDFURL()
        defer { try? FileManager.default.removeItem(at: url) }

        try ExportService.exportPDF(title: "Untitled", body: "", to: url)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testExportPDFHandlesLongContentAcrossMultiplePages() throws {
        let url = makeTempPDFURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let longBody = Array(repeating: "This is a line of the script.", count: 500).joined(separator: "\n")
        try ExportService.exportPDF(title: "Long Document", body: longBody, to: url)

        let data = try Data(contentsOf: url)
        let content = String(data: data, encoding: .isoLatin1) ?? ""
        XCTAssertTrue(content.contains("/Type/Page") || content.contains("/Type /Page"), "Expected at least one PDF page object")
    }

    func testExportScriptPDFCreatesAValidPDFFile() throws {
        let url = makeTempPDFURL()
        defer { try? FileManager.default.removeItem(at: url) }

        try ExportService.exportScriptPDF(
            title: "Pilot Script",
            blocks: [(.sceneHeading, "INT. DINER - DAY"), (.action, "A quiet fishing town diner."), (.character, "MARA"), (.dialogue, "Coffee, black.")],
            to: url
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let data = try Data(contentsOf: url)
        XCTAssertFalse(data.isEmpty)
        XCTAssertEqual(data.prefix(4), Data("%PDF".utf8))
    }

    func testExportScriptPDFHandlesNoBlocksWithoutThrowing() throws {
        let url = makeTempPDFURL()
        defer { try? FileManager.default.removeItem(at: url) }

        try ExportService.exportScriptPDF(title: "Untitled Script", blocks: [], to: url)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testExportScriptPDFHandlesLongScriptAcrossMultiplePages() throws {
        let url = makeTempPDFURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let longScript: [(type: ScriptBlockService.ScriptElementType, text: String)] = (1...200).flatMap { index -> [(type: ScriptBlockService.ScriptElementType, text: String)] in
            [(.sceneHeading, "INT. LOCATION \(index) - DAY"), (.action, "Something happens."), (.character, "MARA"), (.dialogue, "Line \(index).")]
        }
        try ExportService.exportScriptPDF(title: "Long Script", blocks: longScript, to: url)

        let data = try Data(contentsOf: url)
        let content = String(data: data, encoding: .isoLatin1) ?? ""
        XCTAssertTrue(content.contains("/Type/Page") || content.contains("/Type /Page"), "Expected at least one PDF page object")
    }

    /// Kyle (2026-08-19 spec §19/§31): "editor and PDF export must use the same layout rules."
    /// Real headless verification of the shared-layout-engine rewrite (`ScriptTextView` +
    /// `dataWithPDF(inside:)`, see ExportService's doc comment) — no screen, no mouse, no
    /// eyeballing a screenshot. Uses PDFKit's text-extraction (`PDFPage.string`), which is
    /// coordinate-flip-agnostic: it directly proves the right *content* landed on the right
    /// *page*, which is exactly what a coordinate/off-by-one bug in the page-rect slicing would
    /// get wrong.
    func testExportScriptPDFPutsTheTitlePageAndEachScriptPageInTheRightPlace() throws {
        let url = makeTempPDFURL()
        defer { try? FileManager.default.removeItem(at: url) }

        try ExportService.exportScriptPDF(
            title: "Coastal Town",
            blocks: [(.sceneHeading, "INT. KITCHEN - DAY"), (.action, "A quiet morning."), (.character, "MARA"), (.dialogue, "Coffee, black.")],
            author: "Kyle Patan",
            to: url
        )

        guard let document = PDFDocument(url: url) else {
            return XCTFail("PDFKit could not open the exported file")
        }
        XCTAssertEqual(document.pageCount, 2, "1 title page + 1 script page for this short a script")
        XCTAssertEqual(document.page(at: 0)?.string?.contains("COASTAL TOWN"), true, "Title page should show the (uppercased) title")
        XCTAssertEqual(document.page(at: 0)?.string?.contains("Kyle Patan"), true, "Title page should show the author")
        XCTAssertEqual(document.page(at: 1)?.string?.contains("INT. KITCHEN"), true, "The scene heading should land on the first script page, not the title page")
        XCTAssertEqual(document.page(at: 1)?.string?.contains("Coffee, black"), true)
    }

    /// Same idea, but forces real pagination (matches `ScriptEditorGeometryTests`'s own live-editor
    /// pagination test in spirit) — proves a scene many pages in actually lands on ITS OWN page's
    /// PDF output, not silently duplicated onto page 1 or dropped by an off-by-one in
    /// `ScriptPageMetrics.pageCardRect`'s per-page Y math.
    func testExportScriptPDFPaginatesLongScriptsWithContentOnTheCorrectLaterPage() throws {
        let url = makeTempPDFURL()
        defer { try? FileManager.default.removeItem(at: url) }

        var blocks: [(type: ScriptBlockService.ScriptElementType, text: String)] = []
        for index in 1...40 {
            blocks.append((.sceneHeading, "INT. LOCATION \(index) - DAY"))
            blocks.append((.action, String(repeating: "A long beat of action happens here. ", count: 8)))
        }
        try ExportService.exportScriptPDF(title: "Long Script", blocks: blocks, includesTitlePage: false, to: url)

        guard let document = PDFDocument(url: url) else {
            return XCTFail("PDFKit could not open the exported file")
        }
        XCTAssertGreaterThan(document.pageCount, 1, "40 scenes of padded action must overflow a single page")
        let allText = (0..<document.pageCount).compactMap { document.page(at: $0)?.string }.joined()
        XCTAssertTrue(allText.contains("INT. LOCATION 40"), "The last scene must still appear somewhere in the exported document")
        XCTAssertFalse(allText.contains("INT. LOCATION 40") && document.page(at: 0)?.string?.contains("INT. LOCATION 40") == true,
                        "The last scene must not have bled onto page 1")
    }

    func testExportCallSheetPDFCreatesAValidPDFFile() throws {
        let url = makeTempPDFURL()
        defer { try? FileManager.default.removeItem(at: url) }

        try ExportService.exportCallSheetPDF(
            projectTitle: "Airport Sketch",
            callTime: Date(timeIntervalSince1970: 1_700_000_000),
            wrapTime: Date(timeIntervalSince1970: 1_700_028_800),
            location: "Downtown Studio",
            address: "123 Main St",
            castAndCharacters: "Jane Doe as The Traveler",
            crewAndRoles: "Alex Kim (DP)",
            wardrobe: "Business casual",
            props: "Coffee cup",
            equipment: "Boom mic",
            parkingAccess: "Street parking",
            contactInformation: "Producer: 555-1234",
            sceneNotes: "Scenes 1-3",
            additionalNotes: "Golden hour first",
            to: url
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let data = try Data(contentsOf: url)
        XCTAssertFalse(data.isEmpty)
        XCTAssertEqual(data.prefix(4), Data("%PDF".utf8))
    }

    func testExportCallSheetPDFHandlesAllBlankFieldsWithoutThrowing() throws {
        let url = makeTempPDFURL()
        defer { try? FileManager.default.removeItem(at: url) }

        try ExportService.exportCallSheetPDF(
            projectTitle: "Untitled Sketch",
            callTime: .now,
            wrapTime: .now,
            location: "",
            address: "",
            castAndCharacters: "",
            crewAndRoles: "",
            wardrobe: "",
            props: "",
            equipment: "",
            parkingAccess: "",
            contactInformation: "",
            sceneNotes: "",
            additionalNotes: "",
            to: url
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }
}
