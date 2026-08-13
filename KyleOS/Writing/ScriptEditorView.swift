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
/// Deliberately still deferred to a later increment: PDF export of scripts. Auto-uppercasing,
/// the scene navigator (§6.10), and character/scene-heading suggestions (§6.8/§6.9) — all
/// originally deferred too — have since been added.
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
    /// Set once by ScriptEditorRepresentable right after creation — needed for the
    /// character/scene-heading suggestions below (PRD §6.8/§6.9).
    var document: ScriptBlockService.Document?

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

    /// PRD §6.8/§6.9: known character names and scene headings, offered via AppKit's native
    /// completion UI (triggered by the standard macOS completion key, Escape by default) —
    /// "The user can always type manually," so this is a suggestion mechanism, not forced
    /// autocomplete, matching that requirement without hand-building a custom popover.
    private func currentElementType() -> ScriptBlockService.ScriptElementType {
        guard let storage = textStorage else { return .action }
        return ScriptFormatting.type(at: selectedRange().location, in: storage)
    }

    /// Widened to the whole current paragraph for Character/Scene Heading blocks so multi-word
    /// names ("SHERIFF COLE") and full headings ("INT. DINER - DAY") complete as a unit, rather
    /// than NSTextView's default single-word range.
    override var rangeForUserCompletion: NSRange {
        guard let storage = textStorage else { return super.rangeForUserCompletion }
        let type = currentElementType()
        guard type == .character || type == .sceneHeading else { return super.rangeForUserCompletion }
        return (storage.string as NSString).paragraphRange(for: selectedRange())
    }

    override func completions(
        forPartialWordRange charRange: NSRange,
        indexOfSelectedItem index: UnsafeMutablePointer<Int>
    ) -> [String]? {
        guard let document, let storage = textStorage else { return nil }
        let partial = (storage.string as NSString).substring(with: charRange)
        let candidates: [String]
        switch currentElementType() {
        case .character: candidates = ScriptBlockService.knownCharacterNames(for: document)
        case .sceneHeading: candidates = ScriptBlockService.sceneHeadingSuggestions(for: document)
        default: return nil
        }
        guard !partial.isEmpty else { return candidates }
        return candidates.filter { $0.hasPrefix(partial.uppercased()) }
    }
}

struct ScriptEditorRepresentable: NSViewRepresentable {
    let document: ScriptBlockService.Document
    let onChange: ([(type: ScriptBlockService.ScriptElementType, text: String)]) -> Void
    /// PRD §6.10's scene navigator "jump" target — a paragraph index, not a block ID, since
    /// `replaceAllBlocks` gives every block a fresh ID on every edit (see ScriptBlockService's
    /// `sceneHeadings(for:)` doc comment).
    @Binding var scrollToParagraphIndex: Int?

    func makeNSView(context: Context) -> NSScrollView {
        let textView = ScriptTextView()
        textView.document = document
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

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let index = scrollToParagraphIndex, let textView = nsView.documentView as? NSTextView, let storage = textView.textStorage else { return }
        if let range = Self.paragraphRange(at: index, in: storage) {
            textView.scrollRangeToVisible(range)
            textView.setSelectedRange(NSRange(location: range.location, length: 0))
            textView.window?.makeFirstResponder(textView)
        }
        DispatchQueue.main.async { scrollToParagraphIndex = nil }
    }

    static func paragraphRange(at index: Int, in storage: NSTextStorage) -> NSRange? {
        let fullString = storage.string as NSString
        guard fullString.length > 0 else { return nil }
        var location = 0
        var currentIndex = 0
        while location < fullString.length {
            let paragraphRange = fullString.paragraphRange(for: NSRange(location: location, length: 0))
            if currentIndex == index { return paragraphRange }
            currentIndex += 1
            location = paragraphRange.location + paragraphRange.length
            if paragraphRange.length == 0 { break }
        }
        return nil
    }

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
    @State private var scrollToParagraphIndex: Int?

    private var sceneHeadings: [ScriptBlockService.ScriptBlock] {
        ScriptBlockService.sceneHeadings(for: document)
    }

    var body: some View {
        HSplitView {
            sceneNavigator
                .frame(minWidth: 160, idealWidth: 200, maxWidth: 260)
            ScriptEditorRepresentable(
                document: document,
                onChange: { entries in
                    ScriptBlockService.replaceAllBlocks(for: document, with: entries, context: context)
                    document.updatedAt = .now
                    try? context.save()
                },
                scrollToParagraphIndex: $scrollToParagraphIndex
            )
            .frame(minWidth: 400, maxWidth: .infinity)
        }
        .navigationTitle(document.title)
        .onAppear {
            if let project = document.project {
                ProjectService.recordLastOpenedDocument(document, in: project)
                try? context.save()
            }
        }
    }

    /// PRD §6.10: "A scene navigator should allow jumping between scenes."
    private var sceneNavigator: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Scenes").font(.headline).padding(8)
            if sceneHeadings.isEmpty {
                Text("No scenes yet.").foregroundStyle(.secondary).font(.caption).padding(.horizontal, 8)
            } else {
                List(Array(sceneHeadings.enumerated()), id: \.offset) { _, block in
                    Button {
                        scrollToParagraphIndex = block.order
                    } label: {
                        Text(block.text.isEmpty ? "(untitled scene)" : block.text)
                            .font(.caption)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
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
