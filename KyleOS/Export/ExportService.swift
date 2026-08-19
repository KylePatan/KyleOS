import AppKit
import PDFKit

/// File management/export architectural boundary (CLAUDE.md §4), kept separate from Persistence
/// and from the Writing views themselves. PRD §6.20: "Writing should support clean PDF export...
/// without Kyle OS interface, timer, progress, or internal panels." AppKit interop is justified
/// here per CLAUDE.md §3 — PDF generation and file save dialogs are native macOS behavior with no
/// SwiftUI equivalent.
enum ExportService {
    enum ExportError: Error {
        case renderingFailed
    }

    /// US Letter with 1" margins — PDF export has no PRD-specified page size/format decision
    /// gate, so this is a simple documented default (CLAUDE.md §13) rather than a configurable
    /// option not yet asked for.
    static func exportPDF(title: String, body: String, to url: URL) throws {
        let result = NSMutableAttributedString(
            string: title + "\n\n",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 18)]
        )
        result.append(NSAttributedString(string: body, attributes: [.font: WritingSurfaceFont.nsFont(size: 12)]))
        try render(result, to: url)
    }

    /// Kyle (2026-08-19, screenplay spec §19/§31): "Editor pagination and PDF pagination must use
    /// the same layout rules/source of truth... Do not build one layout engine for the editor and
    /// a completely unrelated one for export." This used to render through `NSPrintOperation`'s
    /// own automatic pagination — a genuinely separate mechanism from the editor's
    /// `NSTextContainer.exclusionPaths` pagination, with no guarantee the two ever agreed on where
    /// a page actually breaks. Now: build an *actual* `ScriptTextView` (the exact class the editor
    /// uses, `PrintableScriptTextView` only overrides pagination lookahead + the on-screen-only
    /// drop shadow), paginate it exactly like the editor does, and hand each page's own rect to
    /// `NSView.dataWithPDF(inside:)` — AppKit's own well-established "give me a correct standalone
    /// PDF of this rect of my view" API, which handles the coordinate-space/flip correctness
    /// internally rather than this file guessing at it. `PDFKit` then merges those per-page PDFs
    /// (title page + each script page) into one file. The visible result: whatever page a line
    /// falls on inside Kyle OS is the literal same page it prints on — same method, same pixels,
    /// not just "should match."
    static func exportScriptPDF(
        title: String,
        blocks: [(type: ScriptBlockService.ScriptElementType, text: String)],
        showsSceneNumbers: Bool = false,
        includesTitlePage: Bool = true,
        author: String = "Kyle Patan",
        to url: URL
    ) throws {
        let content = NSMutableAttributedString()
        for block in blocks {
            content.append(NSAttributedString(string: block.text + "\n", attributes: ScriptFormatting.attributes(for: block.type)))
        }

        let textView = PrintableScriptTextView(
            frame: NSRect(x: 0, y: 0, width: ScriptPageMetrics.pageWidth, height: ScriptPageMetrics.pageStride)
        )
        textView.showsSceneNumbers = showsSceneNumbers
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: ScriptPageMetrics.pageWidth, height: .greatestFiniteMagnitude)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        // The exported page IS the container, 1:1 — no surrounding scroll area to center within
        // (that centering is `ScriptTextView.setFrameSize`'s job for the on-screen editor only).
        textView.textContainerInset = .zero
        textView.textStorage?.setAttributedString(content)
        textView.didChangeText()

        guard let layoutManager = textView.layoutManager, let textContainer = textView.textContainer else {
            throw ExportError.renderingFailed
        }
        layoutManager.ensureLayout(for: textContainer)
        let scriptPageCount = max(textView.definedPageCount, 1)

        let combined = PDFDocument()
        var insertIndex = 0

        if includesTitlePage {
            let titleView = TitlePageView(title: title, author: author)
            let pdfData = titleView.dataWithPDF(inside: titleView.bounds)
            if let titleDocument = PDFDocument(data: pdfData), let titlePage = titleDocument.page(at: 0) {
                combined.insert(titlePage, at: insertIndex)
                insertIndex += 1
            }
        }

        for page in 1...scriptPageCount {
            let pageRect = ScriptPageMetrics.pageCardRect(forPage: page, containerOrigin: .zero)
            let pdfData = textView.dataWithPDF(inside: pageRect)
            guard let pageDocument = PDFDocument(data: pdfData), let pdfPage = pageDocument.page(at: 0) else {
                throw ExportError.renderingFailed
            }
            combined.insert(pdfPage, at: insertIndex)
            insertIndex += 1
        }

        guard combined.write(to: url) else {
            throw ExportError.renderingFailed
        }
    }

    /// PRD §9.4/§9.5: "Kyle OS should be able to export the Script and Call Sheet as normal PDF
    /// files suitable for dragging into an email." Takes plain fields rather than the CallSheet
    /// model itself, keeping this file's only domain dependency the existing ScriptBlockService
    /// one — Export stays a clean architectural boundary (CLAUDE.md §4), not coupled to
    /// SketchProductionService. Blank fields are omitted rather than printed as empty lines.
    static func exportCallSheetPDF(
        projectTitle: String,
        callTime: Date,
        wrapTime: Date,
        location: String,
        address: String,
        castAndCharacters: String,
        crewAndRoles: String,
        wardrobe: String,
        props: String,
        equipment: String,
        parkingAccess: String,
        contactInformation: String,
        sceneNotes: String,
        additionalNotes: String,
        to url: URL
    ) throws {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .short

        let result = NSMutableAttributedString(
            string: "CALL SHEET\n\(projectTitle)\n\n",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 18)]
        )
        func appendField(_ label: String, _ value: String) {
            guard !value.isEmpty else { return }
            result.append(NSAttributedString(string: "\(label): ", attributes: [.font: NSFont.boldSystemFont(ofSize: 12)]))
            result.append(NSAttributedString(string: "\(value)\n", attributes: [.font: NSFont.systemFont(ofSize: 12)]))
        }
        appendField("Call Time", dateFormatter.string(from: callTime))
        appendField("Wrap Time", dateFormatter.string(from: wrapTime))
        appendField("Location", location)
        appendField("Address", address)
        appendField("Cast / Characters", castAndCharacters)
        appendField("Crew / Roles", crewAndRoles)
        appendField("Wardrobe", wardrobe)
        appendField("Props", props)
        appendField("Equipment", equipment)
        appendField("Parking / Access", parkingAccess)
        appendField("Contact Information", contactInformation)
        appendField("Scene Notes", sceneNotes)
        appendField("Additional Notes", additionalNotes)
        try render(result, to: url)
    }

    private static func render(_ content: NSAttributedString, to url: URL) throws {
        let pageSize = NSSize(width: 612, height: 792)
        let textView = NSTextView(frame: NSRect(origin: .zero, size: pageSize))
        textView.textStorage?.setAttributedString(content)

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
}

/// See `exportScriptPDF`'s doc comment — the export-time twin of the editor's `ScriptTextView`.
/// Pins pagination to exactly the content's real page count (no lookahead blank page — that's a
/// live-editing UX nicety, not something a PDF should ever show) and turns off the on-screen-only
/// drop shadow so a real printed page doesn't carry a stray gray smear around it.
private final class PrintableScriptTextView: ScriptTextView {
    override var wantsLookaheadPage: Bool { false }
    override var wantsPageShadow: Bool { false }
}

/// Spec §15: a clean, minimal spec-script Title Page — title block centered in the upper third,
/// "Written by" + author beneath it. Deliberately not wired to any new persisted per-document
/// field yet (no custom byline/contact-info/based-on credit) — that's a real schema decision
/// (CLAUDE.md §13), left for its own pass once Kyle actually wants to customize it; this ships the
/// spec's own minimal default structure now rather than blocking Title Page support on that.
private final class TitlePageView: NSView {
    private let title: String
    private let author: String

    init(title: String, author: String) {
        self.title = title
        self.author = author
        super.init(frame: NSRect(x: 0, y: 0, width: ScriptPageMetrics.pageWidth, height: ScriptPageMetrics.pageHeight))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        bounds.fill()

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: WritingSurfaceFont.nsFont(size: 14),
            .foregroundColor: NSColor.black
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: WritingSurfaceFont.nsFont(size: 12),
            .foregroundColor: NSColor.black
        ]

        func drawCentered(_ text: String, attributes: [NSAttributedString.Key: Any], atY y: CGFloat) -> CGFloat {
            let size = text.size(withAttributes: attributes)
            let x = (ScriptPageMetrics.pageWidth - size.width) / 2
            text.draw(at: NSPoint(x: x, y: y), withAttributes: attributes)
            return y + size.height + 20
        }

        var y = ScriptPageMetrics.pageHeight / 3
        y = drawCentered(title.uppercased(), attributes: titleAttributes, atY: y)
        y = drawCentered("Written by", attributes: bodyAttributes, atY: y + 16)
        _ = drawCentered(author, attributes: bodyAttributes, atY: y)
    }
}
