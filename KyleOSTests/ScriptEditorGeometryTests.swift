import XCTest
@testable import KyleOS

/// Kyle (2026-08-19): "do you really need to be using my mouse to do this?" — the 2026-08-18
/// centering bug ("It's shifted right now") was chased twice via screenshot/coordinate-click
/// automation, which also caused a real safety incident (a stray click landed on an unrelated
/// window). These tests check the actual AppKit geometry numbers `ScriptTextView` computes
/// directly — no window, no screen, no mouse — which is both safer and strictly more precise than
/// eyeballing a screenshot.
final class ScriptEditorGeometryTests: XCTestCase {
    func testSetFrameSizeCentersTheFixedWidthPageWithinAWiderView() {
        let textView = ScriptTextView(frame: .zero)
        let wideViewWidth: CGFloat = 900

        textView.setFrameSize(NSSize(width: wideViewWidth, height: 400))

        let expectedInset = (wideViewWidth - ScriptPageMetrics.pageWidth) / 2
        XCTAssertEqual(textView.textContainerInset.width, expectedInset, accuracy: 0.01)
        XCTAssertEqual(textView.textContainerOrigin.x, expectedInset, accuracy: 0.01,
                        "The container's real on-screen origin must reflect the centering inset, not just the stored inset value")
    }

    func testSetFrameSizeNeverProducesANegativeInsetWhenTheViewIsNarrowerThanThePage() {
        let textView = ScriptTextView(frame: .zero)
        textView.setFrameSize(NSSize(width: 300, height: 400))
        XCTAssertGreaterThanOrEqual(textView.textContainerInset.width, 0)
    }

    func testPageIsTrueUSLetterDimensions() {
        XCTAssertEqual(ScriptPageMetrics.pageWidth, 612, "8.5in at 72pt/in")
        XCTAssertEqual(ScriptPageMetrics.pageHeight, 792, "11in at 72pt/in")
    }

    func testActionMarginsAre1_5InLeftAnd1InRight() {
        let style = ScriptFormatting.paragraphStyle(for: .action)
        XCTAssertEqual(style.headIndent, 108, accuracy: 0.01)
        XCTAssertEqual(style.tailIndent, -72, accuracy: 0.01)
    }

    func testDialogueColumnIs3_5InWideCenteredWithin2_5InMargins() {
        let style = ScriptFormatting.paragraphStyle(for: .dialogue)
        XCTAssertEqual(style.headIndent, 180, accuracy: 0.01)
        XCTAssertEqual(style.tailIndent, -180, accuracy: 0.01)
        let columnWidth = ScriptPageMetrics.pageWidth + style.tailIndent - style.headIndent
        XCTAssertEqual(columnWidth, 252, accuracy: 0.01, "612 - 180 - 180 = 252pt = 3.5in")
    }

    func testCharacterCueStartsAtApproximately3_7InFromTheLeftEdge() {
        let style = ScriptFormatting.paragraphStyle(for: .character)
        XCTAssertEqual(style.headIndent, 266.4, accuracy: 0.1)
    }

    func testTransitionIsRightAlignedEndingAt1InFromTheRightEdge() {
        let style = ScriptFormatting.paragraphStyle(for: .transition)
        XCTAssertEqual(style.alignment, .right)
        XCTAssertEqual(style.tailIndent, -72, accuracy: 0.01)
    }

    func testShotGeneralAndActBreakAreRealElementTypesWithFormatting() {
        for type: ScriptBlockService.ScriptElementType in [.shot, .general, .actBreak] {
            _ = ScriptFormatting.attributes(for: type) // must not crash on an unhandled case
        }
        XCTAssertTrue(ScriptFormatting.autoUppercases(.shot))
        XCTAssertTrue(ScriptFormatting.autoUppercases(.actBreak))
        XCTAssertFalse(ScriptFormatting.autoUppercases(.general))
    }

    func testEmptyDocumentPaginatesToExactlyOnePageWhenNoLookaheadIsWanted() {
        final class NoLookaheadTextView: ScriptTextView {
            override var wantsLookaheadPage: Bool { false }
        }
        let textView = NoLookaheadTextView(frame: NSRect(x: 0, y: 0, width: ScriptPageMetrics.pageWidth, height: ScriptPageMetrics.pageStride))
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: ScriptPageMetrics.pageWidth, height: .greatestFiniteMagnitude)
        textView.textStorage?.setAttributedString(NSAttributedString(string: ""))
        textView.didChangeText()
        XCTAssertEqual(textView.definedPageCount, 1)
    }

    /// Regression test for a real bug found while building the shared editor/PDF layout engine:
    /// pagination used to be a single measure-then-rebuild pass, which is only correct when the
    /// exclusion bands already active at measurement time happen to match the final page count.
    /// Loading a long document in one shot (exactly what `ScriptEditorRepresentable.makeNSView`
    /// does when opening an existing script, and what `ExportService` does for every export)
    /// starts from just 1 page's worth of exclusion, so a script that actually needs many pages
    /// used to get an under-estimated page count — and any content past the last *defined* page
    /// had nowhere to land, silently vanishing rather than just wrapping. This proves the fix: the
    /// very last paragraph must fall inside a page `updatePagination` actually defined.
    func testBulkLoadingALongScriptConvergesPaginationInsteadOfDroppingTheTail() {
        final class NoLookaheadTextView: ScriptTextView {
            override var wantsLookaheadPage: Bool { false }
        }
        let textView = NoLookaheadTextView(frame: NSRect(x: 0, y: 0, width: ScriptPageMetrics.pageWidth, height: ScriptPageMetrics.pageStride))
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: ScriptPageMetrics.pageWidth, height: .greatestFiniteMagnitude)

        let content = NSMutableAttributedString()
        for index in 1...40 {
            content.append(NSAttributedString(string: "INT. LOCATION \(index) - DAY\n", attributes: ScriptFormatting.attributes(for: .sceneHeading)))
            content.append(NSAttributedString(string: String(repeating: "A long beat of action happens here. ", count: 8) + "\n", attributes: ScriptFormatting.attributes(for: .action)))
        }
        textView.textStorage?.setAttributedString(content)
        textView.didChangeText() // ONE call, matching the real bulk-load call site — not per-keystroke

        guard let layoutManager = textView.layoutManager, let textContainer = textView.textContainer else {
            return XCTFail("Missing text system")
        }
        layoutManager.ensureLayout(for: textContainer)
        let lastGlyphIndex = layoutManager.numberOfGlyphs - 1
        XCTAssertGreaterThan(lastGlyphIndex, 0)
        let lastGlyphRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: lastGlyphIndex, length: 1), in: textContainer)
        let definedHeight = CGFloat(textView.definedPageCount) * ScriptPageMetrics.pageStride
        XCTAssertLessThan(lastGlyphRect.maxY, definedHeight, "The last glyph in the document must fall within a page pagination actually defined, not past it")
    }

    func testLiveEditingKeepsAWritableLookaheadPageAheadOfContent() {
        let textView = ScriptTextView(frame: NSRect(x: 0, y: 0, width: ScriptPageMetrics.pageWidth, height: ScriptPageMetrics.pageStride))
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: ScriptPageMetrics.pageWidth, height: .greatestFiniteMagnitude)
        textView.textStorage?.setAttributedString(NSAttributedString(string: "INT. KITCHEN - DAY", attributes: ScriptFormatting.attributes(for: .sceneHeading)))
        textView.didChangeText()
        XCTAssertEqual(textView.definedPageCount, 2, "One real page of content plus the live-editing lookahead page")
    }
}
