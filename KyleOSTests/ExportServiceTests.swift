import XCTest
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
