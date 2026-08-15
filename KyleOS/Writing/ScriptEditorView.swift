import SwiftUI
import AppKit
import SwiftData
import UniformTypeIdentifiers

/// Decision Gate A's chosen architecture (docs/PHASE_DECISION_REGISTER.md, resolved with Kyle):
/// AppKit/TextKit wrapped for SwiftUI, not plain SwiftUI text components — the only approach that
/// supports custom Enter/Tab key-driven element transitions and per-paragraph structured typing
/// the PRD requires (§6.7). One continuous NSTextStorage; each paragraph carries a custom
/// `.scriptElementType` attribute identifying its ScriptElementType, which drives both the
/// paragraph's visual formatting and Enter/Tab's transition behavior.
///
/// Auto-uppercasing, the scene navigator (§6.10), character/scene-heading suggestions
/// (§6.8/§6.9), and PDF export (§6.20) — all originally deferred from the first increment —
/// have since been added, closing out every Script Editor requirement that doesn't depend on
/// another module that doesn't exist yet (e.g. §6.14's "Create Script from Scene Outline").
///
/// 2026-08-15 WriterDuet-feel pass (Kyle, hands-on after first real use): direct Cmd+letter
/// hotkeys for element types (`ScriptTextView.performKeyEquivalent`), Enter after Dialogue now
/// returns to Action instead of another Character cue, Enter on Action opens the element-type
/// menu instead of silently continuing, and Return no longer gets swallowed by the character-name
/// completion popup (`insertCompletion`) — see each override's own doc comment for the reasoning.
private extension NSAttributedString.Key {
    static let scriptElementType = NSAttributedString.Key("KyleOSScriptElementType")
}

/// Internal, not private — ExportService.exportScriptPDF reuses this directly so the exported
/// PDF always visually matches the live editor.
enum ScriptFormatting {
    static func font(for type: ScriptBlockService.ScriptElementType) -> NSFont {
        WritingSurfaceFont.nsFont(size: 12)
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
/// comment) — Enter suggests the natural next element (see ScriptBlockService.suggestedNextType's
/// doc comment), Tab opens a visible element-type menu at the caret, matching PRD §6.7's
/// "keyboard-first" requirement and its explicit fallback ("The editor should offer a visible
/// element selector as a fallback"). Cmd+letter (see `performKeyEquivalent`) is the WriterDuet-
/// style direct hotkey path Kyle asked for on top of that — jump straight to an element type
/// after pressing Enter, no Tab-then-click required.
final class ScriptTextView: NSTextView {
    /// Set once by ScriptEditorRepresentable right after creation — needed for the
    /// character/scene-heading suggestions below (PRD §6.8/§6.9).
    var document: ScriptBlockService.Document?

    /// Action is the one type `ScriptBlockService.suggestedNextType` has no confident next guess
    /// for — Kyle (2026-08-15): pressing Enter while on Action should offer the element-type menu
    /// rather than silently starting another Action paragraph.
    override func insertNewline(_ sender: Any?) {
        let currentType = ScriptFormatting.type(at: max(selectedRange().location - 1, 0), in: textStorage!)
        super.insertNewline(sender)
        if currentType == .action {
            showElementTypeMenu()
            return
        }
        let nextType = ScriptBlockService.suggestedNextType(afterEnterFrom: currentType)
        typingAttributes = ScriptFormatting.attributes(for: nextType)
        applyTypeToCurrentParagraph(nextType)
        triggerLiveSuggestionsIfNeeded(for: nextType)
    }

    /// PRD §6.7's "visible element selector" fallback, made literal: Tab pops up a real menu at
    /// the caret rather than silently cycling through a fixed order — Kyle found the blind cycle
    /// not "smooth" to use. "FADE IN:"/"CUT TO:" are quick-insert Transition text, not separate
    /// element types; picking one replaces the current paragraph's text with that phrase.
    override func insertTab(_ sender: Any?) {
        showElementTypeMenu()
    }

    /// WriterDuet-style direct hotkeys (Kyle, 2026-08-15): "having to click the next 'character'
    /// or 'dialogue' from [the Tab] dropdown is a no go... I like the hot keys." First letter of
    /// each element name, matching his explicit ask — zero mouse interaction, the fast path. Tab's
    /// menu (below) still exists as a visible/discoverable fallback and now shows each hotkey next
    /// to its item, but is no longer the only way to override the guessed element type after
    /// Enter. Trade-off worth knowing: within the script editor specifically, this claims Cmd+A/
    /// Cmd+S/Cmd+P/Cmd+D/Cmd+T away from their usual Select All/Save/Print/Duplicate/New Tab
    /// meanings — none of those are wired to anything in this app today, but flagging it since
    /// it's a real, if minor, standard-shortcut trade-off, not a silent one.
    private static let elementTypeHotkeys: [String: ScriptBlockService.ScriptElementType] = [
        "s": .sceneHeading, "a": .action, "c": .character,
        "d": .dialogue, "p": .parenthetical, "t": .transition
    ]

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           let characters = event.charactersIgnoringModifiers?.lowercased(),
           let type = Self.elementTypeHotkeys[characters] {
            selectElementType(type)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    private static let transitionQuickInserts = ["FADE IN:", "CUT TO:"]
    private static let typeMenuItems: [(String, String, ScriptBlockService.ScriptElementType)] = [
        ("Scene Heading", "s", .sceneHeading),
        ("Action", "a", .action),
        ("Character", "c", .character),
        ("Dialogue", "d", .dialogue),
        ("Parenthetical", "p", .parenthetical),
        ("Transition", "t", .transition)
    ]

    /// Bare letter, no Cmd, once the menu is actually open — Kyle (2026-08-15): "if i hit C...
    /// it doesn't just highlight the 'character' option. It should go straight to that." NSMenu's
    /// default behavior for a bare keystroke is type-ahead (highlight the first match, wait for a
    /// second Enter/click to commit); giving each item a real keyEquivalent with no modifier mask
    /// makes AppKit commit it immediately instead. This only applies while the menu itself is
    /// showing — the *standalone* Cmd+letter hotkeys in `performKeyEquivalent` above still require
    /// Cmd, since without the menu open a bare letter needs to keep inserting normal text.
    private func showElementTypeMenu() {
        let menu = NSMenu()
        for (title, key, type) in Self.typeMenuItems {
            let item = NSMenuItem(title: title, action: #selector(selectElementTypeFromMenu(_:)), keyEquivalent: key)
            item.keyEquivalentModifierMask = []
            item.target = self
            item.representedObject = type
            menu.addItem(item)
        }
        menu.addItem(.separator())
        for phrase in Self.transitionQuickInserts {
            let item = NSMenuItem(title: phrase, action: #selector(selectTransitionPhrase(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = phrase
            menu.addItem(item)
        }

        guard let window else { return }
        let screenRect = firstRect(forCharacterRange: selectedRange(), actualRange: nil)
        let windowRect = window.convertFromScreen(screenRect)
        let viewPoint = convert(windowRect.origin, from: nil)
        menu.popUp(positioning: nil, at: viewPoint, in: self)
    }

    @objc private func selectElementTypeFromMenu(_ sender: NSMenuItem) {
        guard let type = sender.representedObject as? ScriptBlockService.ScriptElementType else { return }
        selectElementType(type)
    }

    private func selectElementType(_ type: ScriptBlockService.ScriptElementType) {
        applyTypeToCurrentParagraph(type)
        typingAttributes = ScriptFormatting.attributes(for: type)
        triggerLiveSuggestionsIfNeeded(for: type)
        didChangeText()
    }

    @objc private func selectTransitionPhrase(_ sender: NSMenuItem) {
        guard let phrase = sender.representedObject as? String, let storage = textStorage else { return }
        let paragraphRange = (storage.string as NSString).paragraphRange(for: selectedRange())
        guard shouldChangeText(in: paragraphRange, replacementString: phrase) else { return }
        storage.replaceCharacters(in: paragraphRange, with: phrase)
        let newRange = NSRange(location: paragraphRange.location, length: (phrase as NSString).length)
        storage.addAttributes(ScriptFormatting.attributes(for: .transition), range: newRange)
        setSelectedRange(NSRange(location: newRange.location + newRange.length, length: 0))
        typingAttributes = ScriptFormatting.attributes(for: .transition)
        didChangeText()
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
        triggerLiveSuggestionsIfNeeded(for: type)
    }

    /// A freshly-created paragraph (right after Enter, before anything's typed into it) is
    /// zero-length, so there's no text run to tag with the new type. But `ScriptFormatting.
    /// type(at:)` in `insertNewline` reads the character just *before* the cursor to identify
    /// "what type is the paragraph I'm currently in" — for an empty paragraph, that's the
    /// preceding newline, which still carries the *previous* paragraph's type attribute if we
    /// only ever tag non-empty ranges. Left alone, that stale tag made pressing Enter again on a
    /// still-empty paragraph misidentify its type (Kyle, 2026-08-15: had to hit Enter twice from
    /// a fresh Action line to open the menu, because the first press still read as the type it
    /// transitioned *from*). Retagging that boundary newline too keeps it consistent.
    private func applyTypeToCurrentParagraph(_ type: ScriptBlockService.ScriptElementType) {
        guard let storage = textStorage else { return }
        let paragraphRange = (storage.string as NSString).paragraphRange(for: selectedRange())
        if paragraphRange.length > 0 {
            storage.addAttributes(ScriptFormatting.attributes(for: type), range: paragraphRange)
        }
        if paragraphRange.location > 0 {
            let precedingNewlineRange = NSRange(location: paragraphRange.location - 1, length: 1)
            storage.addAttributes(ScriptFormatting.attributes(for: type), range: precedingNewlineRange)
        }
    }

    /// PRD §6.8/§6.9: known character names and scene headings. Originally only shown via
    /// AppKit's native completion key (Escape by default) — Kyle found that not discoverable or
    /// "smooth," so Scene Heading/Character blocks now trigger the same native popup
    /// automatically (live, as-you-type) instead of waiting for a manual keystroke. "The user
    /// can always type manually" still holds — this only ever suggests, never forces text.
    private func triggerLiveSuggestionsIfNeeded(for type: ScriptBlockService.ScriptElementType) {
        guard type == .sceneHeading || type == .character else { return }
        complete(nil)
    }

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

    /// Kyle (2026-08-15): "it should be a 'tab' into that. If I'm writing character name and i
    /// press enter, that should automatically go to dialogue." AppKit's completion popup normally
    /// treats Return as "accept the suggestion," which was swallowing the Enter keystroke before
    /// it ever reached `insertNewline` — so finishing a character name and hitting Enter could
    /// silently just accept/dismiss the popup instead of advancing to Dialogue. Now: Tab accepts a
    /// suggestion (matching Tab's role as "confirm and move on" everywhere else in this editor),
    /// Return always falls through to the normal element-transition behavior, keeping whatever
    /// Kyle actually typed rather than substituting the suggestion.
    override func insertCompletion(_ word: String, forPartialWordRange charRange: NSRange, movement: Int, isFinal: Bool) {
        if movement == NSReturnTextMovement {
            insertNewline(nil)
            return
        }
        super.insertCompletion(word, forPartialWordRange: charRange, movement: movement, isFinal: isFinal)
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
        let isFreshBlankScript = textView.textStorage?.length == 0
        if isFreshBlankScript {
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

        // A brand-new script starts in Scene Heading — show INT./EXT. suggestions immediately
        // rather than waiting for the first keystroke, same "make it live" fix as the rest of
        // this pass. Deferred to the next run loop turn since the view has no window yet here.
        if isFreshBlankScript {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
                textView.complete(nil)
            }
        }

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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    exportPDF()
                } label: {
                    Label("Export PDF", systemImage: "square.and.arrow.up")
                }
            }
        }
        .onAppear {
            if let project = document.project {
                ProjectService.recordLastOpenedDocument(document, in: project)
                try? context.save()
            }
        }
    }

    /// PRD §6.20: "Writing should support clean PDF export." Reuses ScriptFormatting so the
    /// exported PDF matches what's on screen (see ExportService.exportScriptPDF's doc comment).
    private func exportPDF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = document.title
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let blocks = ScriptBlockService.blocks(for: document).map { (type: $0.elementType, text: $0.text) }
        try? ExportService.exportScriptPDF(title: document.title, blocks: blocks, to: url)
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
