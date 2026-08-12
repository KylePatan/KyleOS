import AppKit

/// File management/export architectural boundary (CLAUDE.md §4), kept separate from Persistence
/// and from the Writing views themselves. PRD §6.20: "Writing should support clean PDF export...
/// without Kyle OS interface, timer, progress, or internal panels." AppKit interop is justified
/// here per CLAUDE.md §3 — PDF generation and file save dialogs are native macOS behavior with no
/// SwiftUI equivalent.
///
/// Plain-text rendering via NSTextView's built-in print pagination — deliberately not the
/// structured Script Block export the PRD eventually wants for script content (that's Decision
/// Gate A territory, since it needs the script editor's structured data model first). Prose and
/// Act/Scene Outline content is already plain/structured text, so this is a complete, real
/// implementation for what's built so far, not a stand-in.
enum ExportService {
    enum ExportError: Error {
        case renderingFailed
    }

    /// US Letter with 1" margins — PDF export has no PRD-specified page size/format decision
    /// gate, so this is a simple documented default (CLAUDE.md §13) rather than a configurable
    /// option not yet asked for.
    static func exportPDF(title: String, body: String, to url: URL) throws {
        let pageSize = NSSize(width: 612, height: 792)
        let textView = NSTextView(frame: NSRect(origin: .zero, size: pageSize))
        textView.textStorage?.setAttributedString(formattedContent(title: title, body: body))

        let printInfo = NSPrintInfo()
        printInfo.paperSize = pageSize
        printInfo.topMargin = 72
        printInfo.bottomMargin = 72
        printInfo.leftMargin = 72
        printInfo.rightMargin = 72
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.jobDisposition = .save
        printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = url

        let operation = NSPrintOperation(view: textView, printInfo: printInfo)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        guard operation.run() else {
            throw ExportError.renderingFailed
        }
    }

    private static func formattedContent(title: String, body: String) -> NSAttributedString {
        let result = NSMutableAttributedString(
            string: title + "\n\n",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 18)]
        )
        result.append(NSAttributedString(
            string: body,
            attributes: [.font: NSFont.systemFont(ofSize: 12)]
        ))
        return result
    }
}
