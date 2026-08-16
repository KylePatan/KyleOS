import Foundation
import SwiftData

/// Reusable domain actions for the Script Editor's structured blocks (PRD §6.7/§14.3), kept out
/// of views per CLAUDE.md §4.
///
/// The Enter-key transition rule below implements Decision Gate A's "How should structured
/// screenplay blocks behave" question — PRD §6.7: "Enter-key behavior should move naturally
/// between common screenplay elements." Kyle's confirmed convention (2026-08-15, WriterDuet-style
/// pass): a scene heading or transition is followed by action; a character cue is followed by
/// their dialogue; a parenthetical is followed by more dialogue; dialogue returns to action (not
/// back to another character cue) — matching how a beat of dialogue is usually followed by an
/// action beat, not assumed back-and-forth. Action is the one type with no confident next guess —
/// `ScriptTextView.insertNewline` shows the element-type menu instead of silently continuing in
/// Action, so `.action` here reads as "the value if that prompt is dismissed without a pick," not
/// "always what happens next."
///
/// Tab no longer cycles types silently — it now opens a visible element-type menu directly in
/// ScriptTextView (PRD §6.7's "visible element selector" fallback, made literal rather than a
/// blind Tab-to-cycle), so there's no `nextTypeInCycle` here anymore.
enum ScriptBlockService {
    typealias ScriptBlock = KyleOSSchemaV30.ScriptBlock
    typealias ScriptElementType = KyleOSSchemaV30.ScriptElementType
    typealias Document = KyleOSSchemaV30.Document

    /// What Enter after a block of `type` should start next, absent any other signal.
    static func suggestedNextType(afterEnterFrom type: ScriptElementType) -> ScriptElementType {
        switch type {
        case .sceneHeading, .transition: return .action
        case .action: return .action
        case .character: return .dialogue
        case .dialogue: return .action
        case .parenthetical: return .dialogue
        }
    }

    static func blocks(for document: Document) -> [ScriptBlock] {
        document.scriptBlocks.sorted { $0.order < $1.order }
    }

    /// PRD §6.10: "Scene Heading blocks create recognizable scene objects. A scene navigator
    /// should allow jumping between scenes." Each block's `order` doubles as its paragraph index
    /// in the editor's NSTextStorage (they're 1:1 by construction), so callers can jump directly
    /// to a scene without needing a separately-tracked scene identity — useful since
    /// `replaceAllBlocks` gives every block a fresh ID on every edit, but `order` stays
    /// meaningful as "the Nth paragraph" for as long as the jump target stays valid.
    static func sceneHeadings(for document: Document) -> [ScriptBlock] {
        blocks(for: document).filter { $0.elementType == .sceneHeading }
    }

    /// PRD §6.9: "Character names previously used in the project should be suggested when
    /// entering a Character block." Distinct, non-empty names in first-used order. Normalized via
    /// `normalizedCharacterName` so a "(CONT'D)" cue never shows up as a separate suggested name
    /// from its own base character.
    static func knownCharacterNames(for document: Document) -> [String] {
        var seen = Set<String>()
        var names: [String] = []
        for block in blocks(for: document) where block.elementType == .character {
            let name = normalizedCharacterName(block.text)
            guard !name.isEmpty, !seen.contains(name) else { continue }
            seen.insert(name)
            names.append(name)
        }
        return names
    }

    /// Kyle (2026-08-16): "when a character has dialogue and there are no other characters
    /// responding back to them in the same scene (say it is only split by action items), the
    /// lines following the initial line are CHARACTER (CONT'D)." Appended as literal text right
    /// on the Character cue (see `ScriptTextView.applyContinuedSuffixIfNeeded`) rather than
    /// computed separately at display/export time — it then flows through PDF export and
    /// persistence for free, since both already just print/save whatever's in the block's `text`.
    /// Known limitation: this is decided once, when the cue is typed — it does not retroactively
    /// update if the surrounding scene is edited afterward (matches this pass's "not Final
    /// Draft-level feature parity" scope; a live-recompute pass would be a reasonable follow-up).
    static let continuedSuffix = "(CONT'D)"

    /// Strips a trailing "(CONT'D)" so a continued cue's name still matches its own base
    /// character for suggestions and for `shouldMarkContinued`'s own lookback — "MARA (CONT'D)"
    /// and "MARA" must never be treated as different characters.
    static func normalizedCharacterName(_ text: String) -> String {
        var name = text.trimmingCharacters(in: .whitespaces)
        if name.hasSuffix(continuedSuffix) {
            name = String(name.dropLast(continuedSuffix.count)).trimmingCharacters(in: .whitespaces)
        }
        return name
    }

    /// Scans backward through the blocks preceding a newly-typed Character cue for the nearest
    /// other Character cue, stopping at a scene/transition boundary (a new scene never inherits
    /// "who spoke last" from the one before it). Action and Parenthetical are exactly the
    /// "split by action items" case Kyle described — they're skipped over, not treated as
    /// breaking the streak. If the nearest preceding cue names the same character, this one
    /// continues them.
    static func shouldMarkContinued(characterName: String, precedingEntries: [(type: ScriptElementType, text: String)]) -> Bool {
        let normalizedName = normalizedCharacterName(characterName)
        guard !normalizedName.isEmpty else { return false }
        for entry in precedingEntries.reversed() {
            switch entry.type {
            case .sceneHeading, .transition:
                return false
            case .character:
                return normalizedCharacterName(entry.text) == normalizedName
            case .action, .dialogue, .parenthetical:
                continue
            }
        }
        return false
    }

    /// PRD §6.8: "Known project locations" and previously-used scene headings, alongside the
    /// standard INT./EXT./INT.-EXT. prefixes (the user can always type manually — this is
    /// suggestion, not a forced format).
    static func sceneHeadingSuggestions(for document: Document) -> [String] {
        let standardPrefixes = SceneElementType.allCases.map(\.rawValue)
        var seen = Set(standardPrefixes)
        var suggestions = standardPrefixes
        for block in sceneHeadings(for: document) {
            let heading = block.text.trimmingCharacters(in: .whitespaces)
            guard !heading.isEmpty, !seen.contains(heading) else { continue }
            seen.insert(heading)
            suggestions.append(heading)
        }
        return suggestions
    }

    private typealias SceneElementType = KyleOSSchemaV30.SceneLocationType

    /// Syncs a document's entire block array in one operation — the simplest correct way to
    /// persist edits from a free-form NSTextStorage (see ScriptEditorView) back to structured
    /// SwiftData rows, rather than diffing paragraph-by-paragraph. Existing blocks beyond the
    /// new count are deleted; blocks are always saved together, so this can't leave stale rows.
    static func replaceAllBlocks(for document: Document, with entries: [(type: ScriptElementType, text: String)], context: ModelContext) {
        for block in document.scriptBlocks {
            context.delete(block)
        }
        for (index, entry) in entries.enumerated() {
            let block = ScriptBlock(elementType: entry.type, text: entry.text, order: index, document: document)
            context.insert(block)
        }
    }
}
