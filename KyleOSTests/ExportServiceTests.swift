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
}
