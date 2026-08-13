import SwiftUI
import AppKit
import SwiftData

/// Decision Gate A's chosen architecture (docs/PHASE_DECISION_REGISTER.md, resolved with Kyle):
/// AppKit/TextKit wrapped for SwiftUI, not plain SwiftUI text components — the only approach that
/// supports custom Enter/Tab key-driven element transitions and per-paragraph structured typing
/// the PRD requires (§6.7). One continuous NSTextStorage; each paragraph carries a custom
/// `.scriptElementType` attribute identifying its ScriptElementType, which drives both the
/// paragraph's visual formatting and Enter/Tab's transition behavior.
///
/// Deliberately NOT included in this first increment (kept for later, narrower increments,
/// matching how Prose got autosave → timer → export as separate passes): auto-uppercasing scene
/// headings/character cues/transitions while typing, scene navigator, character/location
/// autocomplete (§6.8/§6.9), and PDF export of scripts. This increment's bar is a correct,
/// reliable structured editing core — PRD's own priority order for Decision Gate A: "writing
/// reliability, autosave safety, keyboard flow, and maintainable structured data before
/// attempting Final Draft-level feature parity."
private extension NSAttributedString.Key {
    static let scriptElementType = NSAttributedString.Key("KyleOSScriptElementType")
}

private enum ScriptFormatting {
    static func font(for type: ScriptBlockService.ScriptElementType) -> NSFont {
        NSFont(name: "Courier", size: 12) ?? NSFont.userFixedPitchFont(ofSize: 12)!
    }

    /// Simplified, visually-distinct indentation per element type — deliberately not
    /// industry-exact screenplay margins (PRD explicitly deprioritizes "Final Draft-level
    /// feature parity" for this first pass; exact margins can be tuned later from real usage).
    static func paragraphStyle(for type: ScriptBlockService.ScriptElementType) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        switch type {
        case .sceneHeading, .action:
            style.firstLineHeadIndent = 0
            style.headIndent = 0
        case .character:
            style.firstLineHeadIndent = 200
            style.headIndent = 200
        case .parenthetical:
            style.firstLineHeadIndent = 160
            style.headIndent = 160
            style.tailIndent = -160
        case .dialogue:
            style.firstLineHeadIndent = 100
            style.headIndent = 100
            style.tailIndent = -100
        case .transition:
            style.firstLineHeadIndent = 0
            style.headIndent = 0
            style.alignment = .right
        }
        style.paragraphSpacing = 8
        return style
    }

    static func attributes(for type: ScriptBlockService.ScriptElementType) -> [NSAttributedString.Key: Any] {
        [
            .font: font(for: type),
            .paragraphStyle: paragraphStyle(for: type),
            .scriptElementType: type.rawValue
        ]
    }

    /// PRD §6.7's screenplay convention: scene headings, character cues, and transitions are
    /// conventionally all-caps.
    static func autoUppercases(_ type: ScriptBlockService.ScriptElementType) -> Bool {
        type == .sceneHeading || type == .character || type == .transition
    }

    static func type(at location: Int, in storage: NSTextStorage) -> ScriptBlockService.ScriptElementType {
        guard storage.length > 0 else { return .action }
        let safeLocation = min(location, storage.length - 1)
        guard let raw = storage.attribute(.scriptElementType, at: safeLocation, effectiveRange: nil) as? String,
              let type = ScriptBlockService.ScriptElementType(rawValue: raw) else {
            return .action
        }
        return type
    }
}

/// Custom key-command handling is the entire reason this isn't plain SwiftUI (see file doc
/// comment) — Enter suggests the natural next element, Tab manually cycles the current
/// paragraph's type, matching PRD §6.7's "keyboard-first" requirement and its explicit fallback
/// ("The editor should offer a visible element selector as a fallback" — Tab is that fallback's
/// keyboard equivalent).
final class ScriptTextView: NSTextView {
    override func insertNewline(_ sender: Any?) {
        let currentType = ScriptFormatting.type(at: max(selectedRange().location - 1, 0), in: textStorage!)
        super.insertNewline(sender)
        let nextType = ScriptBlockService.suggestedNextType(afterEnterFrom: currentType)
        typingAttributes = ScriptFormatting.attributes(for: nextType)
        applyTypeToCurrentParagraph(nextType)
    }

    override func insertTab(_ sender: Any?) {
        let currentType = ScriptFormatting.type(at: selectedRange().location, in: textStorage!)
        let nextType = ScriptBlockService.nextTypeInCycle(after: currentType)
        applyTypeToCurrentParagraph(nextType)
        typingAttributes = ScriptFormatting.attributes(for: nextType)
    }

    /// Auto-uppercases scene headings/character cues/transitions while typing — screenplay
    /// convention, PRD §6.7. Reads the type from `typingAttributes` (kept in sync by
    /// insertNewline/insertTab above, and by NSTextView's own default click-to-reposition
    /// behavior) rather than re-deriving from storage, since newly-typed text has no storage
    /// attributes yet.
    override func insertText(_ string: Any, replacementRange: NSRange) {
        guard let text = string as? String, !text.isEmpty else {
            super.insertText(string, replacementRange: replacementRange)
            return
        }
        let rawType = typingAttributes[.scriptElementType] as? String
        let type = rawType.flatMap(ScriptBlockService.ScriptElementType.init) ?? .action
        guard ScriptFormatting.autoUppercases(type) else {
            super.insertText(string, replacementRange: replacementRange)
            return
        }
        super.insertText(text.uppercased(), replacementRange: replacementRange)
    }

    private func applyTypeToCurrentParagraph(_ type: ScriptBlockService.ScriptElementType) {
        guard let storage = textStorage else { return }
        let paragraphRange = (storage.string as NSString).paragraphRange(for: selectedRange())
        guard paragraphRange.length > 0 else { return }
        storage.addAttributes(ScriptFormatting.attributes(for: type), range: paragraphRange)
    }
}

struct ScriptEditorRepresentable: NSViewRepresentable {
    let document: ScriptBlockService.Document
    let onChange: ([(type: ScriptBlockService.ScriptElementType, text: String)]) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let textView = ScriptTextView()
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 20, height: 20)
        textView.textStorage?.setAttributedString(Self.attributedString(for: document))
        if textView.textStorage?.length == 0 {
            textView.typingAttributes = ScriptFormatting.attributes(for: .sceneHeading)
        }

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    static func attributedString(for document: ScriptBlockService.Document) -> NSAttributedString {
        let blocks = ScriptBlockService.blocks(for: document)
        let result = NSMutableAttributedString()
        for block in blocks {
            let paragraph = NSAttributedString(
                string: block.text + "\n",
                attributes: ScriptFormatting.attributes(for: block.elementType)
            )
            result.append(paragraph)
        }
        return result
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let onChange: ([(type: ScriptBlockService.ScriptElementType, text: String)]) -> Void

        init(onChange: @escaping ([(type: ScriptBlockService.ScriptElementType, text: String)]) -> Void) {
            self.onChange = onChange
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView, let storage = textView.textStorage else { return }
            onChange(Self.extractBlocks(from: storage))
        }

        static func extractBlocks(from storage: NSTextStorage) -> [(type: ScriptBlockService.ScriptElementType, text: String)] {
            let fullString = storage.string as NSString
            guard fullString.length > 0 else { return [] }
            var entries: [(type: ScriptBlockService.ScriptElementType, text: String)] = []
            var location = 0
            while location < fullString.length {
                let paragraphRange = fullString.paragraphRange(for: NSRange(location: location, length: 0))
                let type = ScriptFormatting.type(at: paragraphRange.location, in: storage)
                var text = fullString.substring(with: paragraphRange)
                if text.hasSuffix("\n") { text.removeLast() }
                entries.append((type, text))
                location = paragraphRange.location + paragraphRange.length
                if paragraphRange.length == 0 { break }
            }
            return entries
        }
    }
}

struct ScriptEditorView: View {
    let document: ScriptBlockService.Document
    @Environment(\.modelContext) private var context

    var body: some View {
        ScriptEditorRepresentable(document: document) { entries in
            ScriptBlockService.replaceAllBlocks(for: document, with: entries, context: context)
            document.updatedAt = .now
            try? context.save()
        }
        .navigationTitle(document.title)
        .onAppear {
            if let project = document.project {
                ProjectService.recordLastOpenedDocument(document, in: project)
                try? context.save()
            }
        }
    }
}

#Preview {
    let container = PersistenceController.makeInMemoryContainer()
    let context = ModelContext(container)
    let project = ProjectService.createProject(title: "Coastal Town", projectType: .tvPilot, in: context)
    let document = DocumentService.createDocument(title: "Pilot Script", type: .script, in: project, context: context)
    ScriptBlockService.replaceAllBlocks(
        for: document,
        with: [(.sceneHeading, "INT. DINER - DAY"), (.action, "A quiet fishing town diner."), (.character, "MARA"), (.dialogue, "Coffee, black.")],
        context: context
    )
    return NavigationStack {
        ScriptEditorView(document: document)
    }
    .modelContainer(container)
}
