import AppKit

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

    /// Script export reuses ScriptFormatting — the exact same per-element formatting the live
    /// editor applies (ScriptEditorView.swift) — so the exported PDF always visually matches
    /// what's on screen, guaranteed by sharing the code rather than keeping two formatting
    /// schemes in sync by hand.
    static func exportScriptPDF(title: String, blocks: [(type: ScriptBlockService.ScriptElementType, text: String)], to url: URL) throws {
        let result = NSMutableAttributedString(
            string: title + "\n\n",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 18)]
        )
        for block in blocks {
            result.append(NSAttributedString(string: block.text + "\n", attributes: ScriptFormatting.attributes(for: block.type)))
        }
        try render(result, to: url)
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
