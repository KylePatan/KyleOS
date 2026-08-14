import Foundation
import SwiftData

/// Reusable domain actions for the Script Editor's structured blocks (PRD §6.7/§14.3), kept out
/// of views per CLAUDE.md §4.
///
/// The Enter-key transition rule below implements Decision Gate A's "How should structured
/// screenplay blocks behave" question — PRD §6.7: "Enter-key behavior should move naturally
/// between common screenplay elements." Standard Final Draft-style industry convention: a scene
/// heading or transition is always followed by action; action stays in action (most action
/// description runs multiple paragraphs); a character cue is followed by their dialogue; a
/// parenthetical is followed by more dialogue; dialogue is followed by a new character cue (the
/// next line of the exchange). Kyle briefly tried a tighter beat-by-beat cycle instead
/// (action->character->dialogue->action) and confirmed after using it for real that he wanted
/// standard convention back — Enter still drives the transitions, just via this mapping.
///
/// Tab no longer cycles types silently — it now opens a visible element-type menu directly in
/// ScriptTextView (PRD §6.7's "visible element selector" fallback, made literal rather than a
/// blind Tab-to-cycle), so there's no `nextTypeInCycle` here anymore.
enum ScriptBlockService {
    typealias ScriptBlock = KyleOSSchemaV29.ScriptBlock
    typealias ScriptElementType = KyleOSSchemaV29.ScriptElementType
    typealias Document = KyleOSSchemaV29.Document

    /// What Enter after a block of `type` should start next, absent any other signal.
    static func suggestedNextType(afterEnterFrom type: ScriptElementType) -> ScriptElementType {
        switch type {
        case .sceneHeading, .transition: return .action
        case .action: return .action
        case .character: return .dialogue
        case .dialogue: return .character
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
    /// entering a Character block." Distinct, non-empty names in first-used order.
    static func knownCharacterNames(for document: Document) -> [String] {
        var seen = Set<String>()
        var names: [String] = []
        for block in blocks(for: document) where block.elementType == .character {
            let name = block.text.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, !seen.contains(name) else { continue }
            seen.insert(name)
            names.append(name)
        }
        return names
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

    private typealias SceneElementType = KyleOSSchemaV29.SceneLocationType

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
