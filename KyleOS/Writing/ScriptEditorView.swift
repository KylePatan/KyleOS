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

/// Kyle (2026-08-19): full "PROFESSIONAL SCREENPLAY EDITOR SPECIFICATION" — resolves Decision Gate
/// A's own open question ("What level of screenplay pagination accuracy is required?") for real,
/// superseding the 2026-08-18 first pass. Core change from that first pass: the text CONTAINER is
/// now the FULL physical page (612×792pt = 8.5×11in, byte-for-byte the same numbers
/// `ExportService`'s PDF page uses), not a narrower "content column" faked wider by a container
/// inset. Each element type positions itself with its own `headIndent`/`tailIndent` (§6-§11's real
/// asymmetric margins — 1.5in left/1in right for Action, ~3.7in for Character, etc.), the same way
/// a real screenplay-formatting engine works. This does two things at once: (1) it makes the
/// *real* asymmetric margins possible on screen at all (`NSTextView.textContainerInset` only ever
/// supported a symmetric inset — that limitation is why the first pass approximated with a
/// narrower symmetric column); (2) it removes the "container narrower than its visual page card"
/// indirection that was the likely source of the unresolved 2026-08-18 centering bug — the
/// container width and the visual page width are now literally the same number, so there's only
/// one thing (`ScriptTextView.setFrameSize`'s centering inset) that can possibly get the
/// horizontal position wrong, not two layered ones.
///
/// Page breaks are still simulated with `NSTextContainer.exclusionPaths` (§19's "editor and PDF
/// must use the same pagination rules" — `ExportService` now builds a `ScriptTextView` of its own
/// and reuses this exact type + its own `draw(_:)`, via `rectForPage`/`knowsPageRange`, instead of
/// a second unrelated layout mechanism — see that file's doc comment).
enum ScriptPageMetrics {
    static let pageWidth: CGFloat = 612       // 8.5in — true US Letter, matches the PDF page exactly
    static let pageHeight: CGFloat = 792      // 11in
    static let topMargin: CGFloat = 72        // 1in
    static let bottomMargin: CGFloat = 72     // 1in
    static let contentHeight: CGFloat = pageHeight - topMargin - bottomMargin // 9in usable height
    static let interPageGap: CGFloat = 32     // purely decorative gap between page cards on screen

    // §5-§11: real asymmetric per-element geometry, measured from the page's own physical edges.
    static let actionLeftMargin: CGFloat = 108        // 1.5in
    static let actionRightMargin: CGFloat = 72        // 1in
    static let characterLeftMargin: CGFloat = 266.4    // ~3.7in
    static let parentheticalLeftMargin: CGFloat = 223.2 // ~3.1in
    static let parentheticalRightMargin: CGFloat = 208.8 // ~2.9in
    static let dialogueLeftMargin: CGFloat = 180      // 2.5in — dialogue column is ~3.5in wide
    static let dialogueRightMargin: CGFloat = 180     // 2.5in
    static let transitionRightMargin: CGFloat = 72    // 1in
    static let pageNumberTopOffset: CGFloat = 36      // 0.5in from the top edge (§14)

    /// Top margin (excluded) + content (flows text) + bottom margin (excluded) + gap (excluded) —
    /// one full repeat unit per page, in the single container's local Y coordinates.
    static let pageStride: CGFloat = topMargin + contentHeight + bottomMargin + interPageGap

    /// Container-local Y where page `number`'s (1-indexed) content band starts.
    static func contentBandStart(page number: Int) -> CGFloat {
        CGFloat(number - 1) * pageStride + topMargin
    }

    /// The exclusion bands (top margin, then bottom-margin+gap) for one page, container-local,
    /// full page width — `NSTextContainer.exclusionPaths` wants these as `NSBezierPath`.
    static func exclusionRects(forPage number: Int) -> [NSRect] {
        let pageStart = CGFloat(number - 1) * pageStride
        let top = NSRect(x: 0, y: pageStart, width: pageWidth, height: topMargin)
        let bottomAndGap = NSRect(
            x: 0, y: pageStart + topMargin + contentHeight,
            width: pageWidth, height: bottomMargin + interPageGap
        )
        return [top, bottomAndGap]
    }

    /// The full "sheet of paper" rect for page `number`, in VIEW-local coordinates —
    /// `containerOrigin` is `ScriptTextView.textContainerOrigin`. Since the container is now
    /// exactly page-width, this rect IS the container's own page band, just offset by the
    /// container's real on-screen origin — no separate "wider than the container" bleed math.
    static func pageCardRect(forPage number: Int, containerOrigin: NSPoint) -> NSRect {
        let pageStart = CGFloat(number - 1) * pageStride
        return NSRect(
            x: containerOrigin.x, y: pageStart + containerOrigin.y,
            width: pageWidth, height: pageHeight
        )
    }

    /// 1-indexed page number containing container-local y-coordinate `y`.
    static func pageNumber(atY y: CGFloat) -> Int {
        max(Int(y / pageStride) + 1, 1)
    }
}

/// Internal, not private — ExportService.exportScriptPDF reuses this directly so the exported
/// PDF always visually matches the live editor.
enum ScriptFormatting {
    static func font(for type: ScriptBlockService.ScriptElementType) -> NSFont {
        WritingSurfaceFont.nsFont(size: 12)
    }

    /// Real screenplay margins (Kyle, 2026-08-19 spec §5-§12), measured from the page's own
    /// physical edges via `ScriptPageMetrics` — `headIndent` is the left position, `tailIndent`
    /// negative is "this many points in from the trailing/right edge" (`NSParagraphStyle`'s own
    /// documented convention for a non-positive tailIndent — already how the original Parenthetical/
    /// Dialogue margins worked before this pass, just now page-relative instead of
    /// container-relative since the container itself is the full page).
    static func paragraphStyle(for type: ScriptBlockService.ScriptElementType) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        let metrics = ScriptPageMetrics.self
        switch type {
        case .sceneHeading, .action, .shot, .general:
            style.firstLineHeadIndent = metrics.actionLeftMargin
            style.headIndent = metrics.actionLeftMargin
            style.tailIndent = -metrics.actionRightMargin
        case .character:
            style.firstLineHeadIndent = metrics.characterLeftMargin
            style.headIndent = metrics.characterLeftMargin
            style.tailIndent = -metrics.actionRightMargin
        case .parenthetical:
            style.firstLineHeadIndent = metrics.parentheticalLeftMargin
            style.headIndent = metrics.parentheticalLeftMargin
            style.tailIndent = -metrics.parentheticalRightMargin
        case .dialogue:
            style.firstLineHeadIndent = metrics.dialogueLeftMargin
            style.headIndent = metrics.dialogueLeftMargin
            style.tailIndent = -metrics.dialogueRightMargin
        case .transition:
            style.firstLineHeadIndent = metrics.actionLeftMargin
            style.headIndent = metrics.actionLeftMargin
            style.tailIndent = -metrics.transitionRightMargin
            style.alignment = .right
        case .actBreak:
            style.firstLineHeadIndent = metrics.actionLeftMargin
            style.headIndent = metrics.actionLeftMargin
            style.tailIndent = -metrics.actionRightMargin
            style.alignment = .center
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

    /// PRD §6.7 + spec §6/§12/§26: scene headings, character cues, transitions, shots, and act
    /// breaks are conventionally all-caps.
    static func autoUppercases(_ type: ScriptBlockService.ScriptElementType) -> Bool {
        switch type {
        case .sceneHeading, .character, .transition, .shot, .actBreak: return true
        case .action, .parenthetical, .dialogue, .general: return false
        }
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
/// Not `final` — `ExportService.PrintableScriptTextView` and a test helper both subclass this to
/// override `wantsLookaheadPage`/`wantsPageShadow` (see those properties' own doc comments) so
/// export/tests can reuse this exact class's pagination + drawing rather than re-implementing it.
class ScriptTextView: NSTextView {
    /// Set once by ScriptEditorRepresentable right after creation — needed for the
    /// character/scene-heading suggestions below (PRD §6.8/§6.9).
    var document: ScriptBlockService.Document?

    /// Kyle (2026-08-18): "a toggle option for numbering scenes when you are writing a script of
    /// any kind." A global, live-editing display preference (not saved per-document/per-project —
    /// scene numbers are a *presentation* choice, the same number sequence is always derivable
    /// from the existing Scene Heading blocks) — `ScriptEditorView` owns the persisted
    /// `@AppStorage` toggle and pushes it down here on every `updateNSView`.
    var showsSceneNumbers: Bool = false {
        didSet { needsDisplay = true }
    }

    /// How many pages worth of exclusion bands are currently defined. For live editing, this is
    /// always at least one page more than the content actually needs (`updatePagination`'s
    /// `+ 1` lookahead), so there's always a visible, writable page ahead of the cursor. For
    /// export (`ExportService`), a `PrintableScriptTextView` subclass pins this to the exact page
    /// count instead — see that type's own doc comment.
    var definedPageCount = 1

    /// Kyle (2026-08-18/19): "the page is way over to your right" / "It's shifted right now" —
    /// AppKit does *not* auto-center a text container narrower than its view; it just places it at
    /// `textContainerInset.width` from the left edge. The 2026-08-19 geometry rewrite (see
    /// `ScriptPageMetrics`'s doc comment) also removed the earlier design's second, harder-to-spot
    /// contributor: the container used to be narrower than the visual "page card" drawn around it
    /// (`contentWidth` vs `visualWidth`), so there were two independent offsets that both had to be
    /// exactly right for the page to look centered. Now the container width IS the page width —
    /// this is the only centering computation left, verified directly (not by screenshot) in
    /// `ScriptEditorGeometryTests`.
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        let centeredInset = max((newSize.width - ScriptPageMetrics.pageWidth) / 2, 0)
        if textContainerInset.width != centeredInset {
            textContainerInset = NSSize(width: centeredInset, height: 0)
        }
    }

    override func didChangeText() {
        super.didChangeText()
        updatePagination()
    }

    /// Kyle (2026-08-18): real pagination, not just a narrower column. Measures how much text is
    /// currently laid out, works out how many pages that needs, and — only when that number
    /// actually changes — rebuilds `textContainer.exclusionPaths` so TextKit naturally flows text
    /// around the gaps between pages instead of through them. See `ScriptPageMetrics`'s doc
    /// comment for why a single NSTextContainer with exclusion paths, instead of one container per
    /// page: it's the only approach that didn't require touching any of this class's existing
    /// custom key-handling overrides.
    ///
    /// `wantsLookaheadPage` is `false` for `PrintableScriptTextView` (export) — a PDF should have
    /// exactly as many pages as the content needs, not one extra blank one.
    var wantsLookaheadPage: Bool { true }

    /// Found while adding the shared editor/PDF layout engine (2026-08-19): a single measure-then-
    /// rebuild pass is only a correct page count when the *current* exclusion bands already match
    /// the *final* page count — true for ordinary live typing (one keystroke rarely changes the
    /// page count by more than one, so a stale one-page-short estimate self-corrects on the very
    /// next keystroke) but NOT true the first time a long, already-written document is loaded in
    /// one shot (`ScriptEditorRepresentable.makeNSView`'s initial load, and every export): with
    /// only 1 page's exclusion band active at measurement time, a script that actually needs, say,
    /// 25 pages gets a one-shot page-count estimate, exclusion paths are built for exactly that
    /// count, and anything that reflows past the last defined band lands in undefined territory
    /// with no further margin bands to push it onto a visible/exportable page — silently dropping
    /// the tail of a long script. Caught by `ExportServiceTests.
    /// testExportScriptPDFPaginatesLongScriptsWithContentOnTheCorrectLaterPage` (the last scene
    /// simply never appeared in the exported PDF at all). Fixed by iterating measure→rebuild until
    /// the page count actually stabilizes, capped so a genuine layout anomaly can't spin forever
    /// rather than just render one page short.
    func updatePagination() {
        guard let layoutManager, let textContainer else { return }
        for _ in 0..<20 {
            layoutManager.ensureLayout(for: textContainer)
            let measuredHeight = layoutManager.usedRect(for: textContainer).height
            // The currently-defined exclusion bands themselves add height that isn't "content" —
            // subtract that back out to estimate how much real content there is, independent of
            // whatever page count is currently defined.
            let excludedHeight = CGFloat(max(definedPageCount, 1)) * (ScriptPageMetrics.topMargin + ScriptPageMetrics.bottomMargin + ScriptPageMetrics.interPageGap)
            let rawContentHeight = max(measuredHeight - excludedHeight, 0)
            let neededPages = max(Int(ceil(rawContentHeight / ScriptPageMetrics.contentHeight)), 1)
            let targetPageCount = wantsLookaheadPage ? neededPages + 1 : neededPages
            guard targetPageCount != definedPageCount else { return }
            definedPageCount = targetPageCount
            rebuildExclusionPaths()
        }
    }

    private func rebuildExclusionPaths() {
        guard let textContainer else { return }
        var rects: [NSRect] = []
        for page in 1...max(definedPageCount, 1) {
            rects.append(contentsOf: ScriptPageMetrics.exclusionRects(forPage: page))
        }
        textContainer.exclusionPaths = rects.map { NSBezierPath(rect: $0) }
        let totalHeight = CGFloat(definedPageCount) * ScriptPageMetrics.pageStride
        setFrameSize(NSSize(width: frame.width, height: max(totalHeight, ScriptPageMetrics.pageStride)))
        needsDisplay = true
    }

    /// Print/PDF export (`PrintableScriptTextView`) draws onto an actual page, so the decorative
    /// drop shadow (correct for the on-screen "sheet of paper on a gray desk" look) would just be a
    /// stray gray smear around real printed content — that subclass turns this off.
    var wantsPageShadow: Bool { true }

    /// Paints each page as a distinct white "sheet" with a soft shadow (the gaps between them show
    /// the surrounding gray scroll background), plus page numbers and — when
    /// `showsSceneNumbers` is on — a scene number in the left margin of every Scene Heading line.
    /// Runs before `super.draw`, and disables the view's own flat background fill
    /// (`drawsBackground = false`, set in `ScriptEditorRepresentable`) so this is the only thing
    /// painting behind the text. Reused verbatim by `PrintableScriptTextView` for PDF export
    /// (spec §19/§31: "editor and PDF export must use the same layout rules") — the same method
    /// draws page 1's on-screen sheet and page 1's actual PDF page, not two independent
    /// implementations that could drift apart.
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else {
            super.draw(dirtyRect)
            return
        }
        let origin = textContainerOrigin
        for page in 1...max(definedPageCount, 1) {
            let cardRect = ScriptPageMetrics.pageCardRect(forPage: page, containerOrigin: origin)
            guard cardRect.intersects(dirtyRect) else { continue }
            context.saveGState()
            if wantsPageShadow {
                context.setShadow(offset: CGSize(width: 0, height: -2), blur: 6, color: NSColor.black.withAlphaComponent(0.25).cgColor)
            }
            NSColor.white.setFill()
            context.fill(cardRect)
            context.restoreGState()

            // §14: no page number on page 1; page 2 reads "2.", right-aligned to the 1in right
            // margin, 0.5in down from the physical page's own top edge.
            let pageNumberText = page == 1 ? "" : "\(page)."
            if !pageNumberText.isEmpty {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: WritingSurfaceFont.nsFont(size: 12),
                    .foregroundColor: NSColor.black
                ]
                let size = pageNumberText.size(withAttributes: attributes)
                let rightEdge = cardRect.maxX - ScriptPageMetrics.actionRightMargin
                let y = cardRect.minY + ScriptPageMetrics.pageNumberTopOffset - size.height
                pageNumberText.draw(at: NSPoint(x: rightEdge - size.width, y: y), withAttributes: attributes)
            }
        }
        if showsSceneNumbers {
            drawSceneNumbers(in: dirtyRect)
        }
        super.draw(dirtyRect)
    }

    /// Kyle (2026-08-18): scene numbers are a live *display* concern, not stored data — always
    /// derived fresh from whatever Scene Heading paragraphs are actually in the live text storage
    /// right now (same live-enumeration approach as `Coordinator.extractBlocks`), so they never
    /// drift out of sync with edits the way a stored/cached number could.
    private func drawSceneNumbers(in dirtyRect: NSRect) {
        guard let storage = textStorage, let layoutManager, let textContainer else { return }
        let fullString = storage.string as NSString
        guard fullString.length > 0 else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: WritingSurfaceFont.nsFont(size: 12),
            .foregroundColor: NSColor.black
        ]
        // `boundingRect(forGlyphRange:in:)` is container-local; `draw(_:)` is view-local — every
        // container rect needs `textContainerOrigin` added before it's usable here.
        let origin = textContainerOrigin
        var location = 0
        var sceneNumber = 0
        while location < fullString.length {
            let paragraphRange = fullString.paragraphRange(for: NSRange(location: location, length: 0))
            if ScriptFormatting.type(at: paragraphRange.location, in: storage) == .sceneHeading {
                sceneNumber += 1
                let glyphRange = layoutManager.glyphRange(forCharacterRange: paragraphRange, actualCharacterRange: nil)
                let lineRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer).offsetBy(dx: origin.x, dy: origin.y)
                if lineRect.intersects(dirtyRect) {
                    let label = "\(sceneNumber)"
                    let size = label.size(withAttributes: attributes)
                    label.draw(at: NSPoint(x: lineRect.minX - size.width - 12, y: lineRect.minY), withAttributes: attributes)
                }
            }
            location = paragraphRange.location + paragraphRange.length
            if paragraphRange.length == 0 { break }
        }
    }

    /// Action is the one type `ScriptBlockService.suggestedNextType` has no confident next guess
    /// for — Kyle (2026-08-15): pressing Enter while on Action should offer the element-type menu
    /// rather than silently starting another Action paragraph.
    override func insertNewline(_ sender: Any?) {
        let currentType = ScriptFormatting.type(at: max(selectedRange().location - 1, 0), in: textStorage!)
        if currentType == .character {
            applyContinuedSuffixIfNeeded()
        }
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

    /// Kyle (2026-08-19 spec §6): Shot/General/Act Break round out the full element set but don't
    /// get a Cmd+letter hotkey of their own — every obvious single letter (S/A/C/D/P/T) is already
    /// claimed above, and these three are used rarely enough that the Tab menu (below) is a fine
    /// primary path.

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
        ("Transition", "t", .transition),
        ("Shot", "", .shot),
        ("General", "", .general),
        ("Act Break", "", .actBreak)
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
    ///
    /// Kyle (2026-08-17): "Screenplay writing is all messed and keeps going to character over
    /// and over and over again" — reproduced live: this override used to also call
    /// `triggerLiveSuggestionsIfNeeded`, re-opening the completion popup on *every single
    /// keystroke*. Once what's been typed exactly matches a candidate (e.g. finishing "INT."),
    /// re-triggering `complete(nil)` again right on that same keystroke duplicates the match
    /// inline ("INT.." was observed) and leaves the popup open into the next Return press, which
    /// AppKit then routes through `insertCompletion` *in addition to* the normal newline path —
    /// double-firing `insertNewline` for one Enter, which is what produced runs of repeated
    /// "CHARACTER (CONT'D)" lines with nothing ever advancing to Dialogue. The popup still opens
    /// live the moment a Character/Scene Heading block is *entered* (`insertNewline`'s nextType
    /// branch, `selectElementType`, and the fresh-blank-script bootstrap in `makeNSView` all still
    /// call it once) — AppKit's own completion window already narrows itself as more is typed
    /// without needing to be re-triggered, so nothing about the "live suggestions" feature itself
    /// is lost by only opening it once per block instead of once per keystroke.
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

    /// Kyle (2026-08-16): a Character cue that resumes the same character after only action (or
    /// parenthetical) beats — no other character's dialogue in between, same scene — reads
    /// "CHARACTER (CONT'D)". Fires right as the cue is finalized (Enter, leaving Character for
    /// Dialogue) so the suffix is literal typed text from here on — see
    /// `ScriptBlockService.continuedSuffix`'s doc comment for why that's the chosen approach and
    /// its one known limitation (decided once, not live-recomputed on later edits).
    ///
    /// `.dropLast()` assumes the paragraph being finalized is the last one `extractBlocks` finds,
    /// true for the normal type-forward-and-press-Enter flow this fires from; editing back into
    /// an earlier Character cue and pressing Enter there is an unhandled edge case, not the
    /// common path this was built for.
    private func applyContinuedSuffixIfNeeded() {
        guard let storage = textStorage else { return }
        var nameRange = (storage.string as NSString).paragraphRange(for: selectedRange())
        if nameRange.length > 0 {
            let lastCharRange = NSRange(location: nameRange.location + nameRange.length - 1, length: 1)
            if (storage.string as NSString).substring(with: lastCharRange) == "\n" {
                nameRange.length -= 1
            }
        }
        let name = (storage.string as NSString).substring(with: nameRange).trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !name.hasSuffix(ScriptBlockService.continuedSuffix) else { return }

        let precedingEntries = ScriptEditorRepresentable.Coordinator.extractBlocks(from: storage)
            .dropLast()
            .map { (type: $0.type, text: $0.text) }
        guard ScriptBlockService.shouldMarkContinued(characterName: name, precedingEntries: precedingEntries) else { return }

        let suffix = " " + ScriptBlockService.continuedSuffix
        let insertRange = NSRange(location: nameRange.location + nameRange.length, length: 0)
        guard shouldChangeText(in: insertRange, replacementString: suffix) else { return }
        storage.replaceCharacters(in: insertRange, with: suffix)
        storage.addAttributes(
            ScriptFormatting.attributes(for: .character),
            range: NSRange(location: insertRange.location, length: (suffix as NSString).length)
        )
        setSelectedRange(NSRange(location: insertRange.location + (suffix as NSString).length, length: 0))
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
    @Binding var showsSceneNumbers: Bool
    @Binding var zoomLevel: CGFloat

    func makeNSView(context: Context) -> NSScrollView {
        let textView = ScriptTextView()
        textView.document = document
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.showsSceneNumbers = showsSceneNumbers
        // Kyle (2026-08-18): "There should also be spell check." A raw NSTextView has none of
        // SwiftUI's TextEditor defaults, so this needs to be explicit — unlike ProseEditorView's
        // plain TextEditor, which already gets it for free. Flagging only (the red underline), not
        // auto-correction: silently rewriting a character name, slang, or a deliberate screenplay
        // convention (e.g. "O.S.", "V.O.") would be actively wrong for this surface. Grammar
        // checking off too — normal grammar rules don't apply to fragment-heavy action lines or
        // all-caps scene headings/character cues.
        textView.isContinuousSpellCheckingEnabled = true
        textView.isGrammarCheckingEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.textStorage?.setAttributedString(Self.attributedString(for: document))
        let isFreshBlankScript = textView.textStorage?.length == 0
        if isFreshBlankScript {
            textView.typingAttributes = ScriptFormatting.attributes(for: .sceneHeading)
        }

        // Real page geometry (ScriptPageMetrics), reusing a plain, well-established TextKit
        // default: the text VIEW stays exactly as wide as the scroll area (`autoresizingMask =
        // [.width]`, same as before this pass), while the text CONTAINER inside it is a fixed
        // `pageWidth` (8.5in, the full physical page — see ScriptPageMetrics's 2026-08-19 doc
        // comment) — centered by `ScriptTextView.setFrameSize` explicitly recomputing
        // `textContainerInset.width` on every resize (AppKit does NOT do this centering on its
        // own — see that override's own doc comment for the bug that taught us that). Everything
        // custom-painted (page cards, page numbers, scene numbers — ScriptTextView.draw) reads
        // the real `textContainerOrigin` back out, so it's always drawn exactly where the
        // container actually sits, not a separately-guessed position. Not setting
        // textContainerInset here at all — `setFrameSize` owns it exclusively from the moment
        // `frame` is first assigned below, so there's only ever one source of truth for it.
        textView.drawsBackground = false
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: ScriptPageMetrics.pageWidth, height: .greatestFiniteMagnitude)
        textView.frame = NSRect(x: 0, y: 0, width: ScriptPageMetrics.pageWidth, height: ScriptPageMetrics.pageStride)

        let scrollView = NSScrollView()
        scrollView.backgroundColor = NSColor.controlBackgroundColor
        scrollView.drawsBackground = true
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        // Kyle (2026-08-19 spec §1/§27): "Zooming the editor changes only the visual scale...
        // must NEVER change margins/wrapping/pagination." `NSScrollView.magnification` scales the
        // rendered pixels of the (unchanged) documentView — it never touches the text container's
        // own size/metrics, so this is the one zoom mechanism that structurally can't leak into
        // layout. `ScriptEditorView` owns the actual zoom level and pushes it down in
        // `updateNSView`.
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.5
        scrollView.maxMagnification = 2.0

        // Establishes the first page's exclusion bands before anything's typed, so page 1 already
        // reads as a real sheet of paper (not the pre-pagination flat text area) the moment the
        // editor opens.
        textView.didChangeText()

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
        guard let textView = nsView.documentView as? ScriptTextView else { return }
        if textView.showsSceneNumbers != showsSceneNumbers {
            textView.showsSceneNumbers = showsSceneNumbers
        }
        // Only push when it actually differs from the binding's last-known value — a live
        // trackpad pinch gesture (also enabled by `allowsMagnification`) sets `nsView.
        // magnification` directly outside this binding; re-asserting the same stored value on
        // every unrelated `updateNSView` pass is a no-op, but re-asserting a STALE one would
        // fight the user's in-progress pinch. `zoomLevel` itself only changes from the toolbar/
        // keyboard controls below, not from reading the gesture back out (a known, minor gap —
        // see ScriptEditorView's own zoom control doc comment).
        if abs(nsView.magnification - zoomLevel) > 0.001 {
            nsView.magnification = zoomLevel
        }
        guard let index = scrollToParagraphIndex, let storage = textView.textStorage else { return }
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
    /// Kyle (2026-08-18): "a toggle option for numbering scenes when you are writing a script of
    /// any kind." Global rather than per-document — see `ScriptTextView.showsSceneNumbers`'s own
    /// doc comment for why. `@AppStorage` (plain UserDefaults) rather than a new SwiftData/
    /// schema field: this is a display preference derivable at any time from the existing Scene
    /// Heading blocks, not document content worth a migration.
    @AppStorage("KyleOS.script.showsSceneNumbers") private var showsSceneNumbers = false
    /// Kyle (2026-08-19 spec §27): "Fit Page, Fit Width, 75%, 90%, 100%, 110%, 125%, 150%...
    /// Command + and Command - should zoom." Fixed-percentage steps only for this pass — Fit
    /// Page/Fit Width need the live on-screen scroll width, which isn't available from plain
    /// SwiftUI state without plumbing a reference to the NSScrollView back out; deferred rather
    /// than half-built. Global per-app-launch state (not per-document), matching `showsSceneNumbers`'s
    /// own "display preference, not document content" reasoning — `@AppStorage` would be equally
    /// valid here but a plain `@State` is enough since a zoom level chosen for one script isn't a
    /// meaningful thing to remember for the next one.
    @State private var scriptZoom: CGFloat = 1.0
    private static let zoomSteps: [CGFloat] = [0.75, 0.9, 1.0, 1.1, 1.25, 1.5]

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
                scrollToParagraphIndex: $scrollToParagraphIndex,
                showsSceneNumbers: $showsSceneNumbers,
                zoomLevel: $scriptZoom
            )
            .frame(minWidth: 400, maxWidth: .infinity)
        }
        .navigationTitle(document.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ForEach(Self.zoomSteps, id: \.self) { step in
                        Button("\(Int(step * 100))%") { scriptZoom = step }
                    }
                } label: {
                    Label("\(Int(scriptZoom * 100))%", systemImage: "magnifyingglass")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    zoomOut()
                } label: {
                    Label("Zoom Out", systemImage: "minus.magnifyingglass")
                }
                .keyboardShortcut("-", modifiers: .command)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    zoomIn()
                } label: {
                    Label("Zoom In", systemImage: "plus.magnifyingglass")
                }
                .keyboardShortcut("=", modifiers: .command)
            }
            ToolbarItem(placement: .primaryAction) {
                Toggle(isOn: $showsSceneNumbers) {
                    Label("Scene Numbers", systemImage: "number")
                }
            }
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

    private func zoomIn() {
        scriptZoom = min(scriptZoom + 0.1, 2.0)
    }

    private func zoomOut() {
        scriptZoom = max(scriptZoom - 0.1, 0.5)
    }

    /// PRD §6.20: "Writing should support clean PDF export." Reuses ScriptFormatting so the
    /// exported PDF matches what's on screen (see ExportService.exportScriptPDF's doc comment).
    private func exportPDF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = document.title
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let blocks = ScriptBlockService.blocks(for: document).map { (type: $0.elementType, text: $0.text) }
        try? ExportService.exportScriptPDF(title: document.title, blocks: blocks, showsSceneNumbers: showsSceneNumbers, to: url)
    }

    /// PRD §6.10: "A scene navigator should allow jumping between scenes." Chrome only — the
    /// editing surface itself (ScriptEditorRepresentable) deliberately stays outside the retro
    /// system, per Kyle's own "Kyle OS interface vs. classic typewriter page" distinction.
    private var sceneNavigator: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SCENES")
                .font(.caption.bold())
                .foregroundStyle(RetroTheme.secondaryText)
                .padding(.horizontal, RetroTheme.sectionPadding)
                .padding(.vertical, RetroTheme.controlSpacing)
                .frame(maxWidth: .infinity, alignment: .leading)
            Rectangle().fill(RetroTheme.border).frame(height: RetroTheme.borderWidth)
            if sceneHeadings.isEmpty {
                Text("No scenes yet.")
                    .foregroundStyle(RetroTheme.secondaryText)
                    .font(.caption)
                    .padding(RetroTheme.sectionPadding)
            } else {
                List(Array(sceneHeadings.enumerated()), id: \.offset) { _, block in
                    Button {
                        scrollToParagraphIndex = block.order
                    } label: {
                        Text(block.text.isEmpty ? "(untitled scene)" : block.text)
                            .font(.caption)
                            .foregroundStyle(RetroTheme.primaryText)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(RetroTheme.panelBackground)
                    .listRowSeparatorTint(RetroTheme.border.opacity(0.5))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(RetroTheme.panelBackground)
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
