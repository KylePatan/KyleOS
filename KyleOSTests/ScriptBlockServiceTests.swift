import XCTest
import SwiftData
@testable import KyleOS

final class ScriptBlockServiceTests: XCTestCase {

    private func makeScriptDocument(context: ModelContext) -> ScriptBlockService.Document {
        let project = ProjectService.createProject(title: "Coastal Town", projectType: .tvPilot, in: context)
        return DocumentService.createDocument(title: "Pilot Script", type: .script, in: project, context: context)
    }

    // MARK: - Enter-key transition convention (Decision Gate A)

    func testSuggestedNextTypeAfterSceneHeadingIsAction() {
        XCTAssertEqual(ScriptBlockService.suggestedNextType(afterEnterFrom: .sceneHeading), .action)
    }

    func testSuggestedNextTypeAfterActionStaysAction() {
        XCTAssertEqual(ScriptBlockService.suggestedNextType(afterEnterFrom: .action), .action)
    }

    func testSuggestedNextTypeAfterCharacterIsDialogue() {
        XCTAssertEqual(ScriptBlockService.suggestedNextType(afterEnterFrom: .character), .dialogue)
    }

    func testSuggestedNextTypeAfterDialogueIsAction() {
        XCTAssertEqual(ScriptBlockService.suggestedNextType(afterEnterFrom: .dialogue), .action)
    }

    func testSuggestedNextTypeAfterParentheticalIsDialogue() {
        XCTAssertEqual(ScriptBlockService.suggestedNextType(afterEnterFrom: .parenthetical), .dialogue)
    }

    func testSuggestedNextTypeAfterTransitionIsAction() {
        XCTAssertEqual(ScriptBlockService.suggestedNextType(afterEnterFrom: .transition), .action)
    }

    // MARK: - Persistence

    func testReplaceAllBlocksCreatesOrderedBlocksMatchingTheirIndex() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let document = makeScriptDocument(context: context)

        ScriptBlockService.replaceAllBlocks(
            for: document,
            with: [(.sceneHeading, "INT. DINER - DAY"), (.action, "Quiet morning."), (.character, "MARA"), (.dialogue, "Coffee, black.")],
            context: context
        )
        try context.save()

        let blocks = ScriptBlockService.blocks(for: document)
        XCTAssertEqual(blocks.map(\.elementType), [.sceneHeading, .action, .character, .dialogue])
        XCTAssertEqual(blocks.map(\.text), ["INT. DINER - DAY", "Quiet morning.", "MARA", "Coffee, black."])
        XCTAssertEqual(blocks.map(\.order), [0, 1, 2, 3])
    }

    // MARK: - Scene navigator

    func testSceneHeadingsReturnsOnlySceneHeadingBlocksInDocumentOrder() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let document = makeScriptDocument(context: context)

        ScriptBlockService.replaceAllBlocks(
            for: document,
            with: [
                (.sceneHeading, "INT. DINER - DAY"),
                (.action, "Quiet morning."),
                (.sceneHeading, "EXT. DOCKS - NIGHT"),
                (.action, "The tide is out."),
                (.transition, "CUT TO:"),
                (.sceneHeading, "INT. DINER - CONTINUOUS")
            ],
            context: context
        )
        try context.save()

        let sceneHeadings = ScriptBlockService.sceneHeadings(for: document)
        XCTAssertEqual(sceneHeadings.map(\.text), ["INT. DINER - DAY", "EXT. DOCKS - NIGHT", "INT. DINER - CONTINUOUS"])
        XCTAssertEqual(sceneHeadings.map(\.order), [0, 2, 5], "Order should reflect each scene heading's real paragraph position, not its position within just the scene list")
    }

    func testSceneHeadingsIsEmptyWhenScriptHasNone() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let document = makeScriptDocument(context: context)

        ScriptBlockService.replaceAllBlocks(for: document, with: [(.action, "No scenes yet.")], context: context)
        try context.save()

        XCTAssertTrue(ScriptBlockService.sceneHeadings(for: document).isEmpty)
    }

    // MARK: - Character/location suggestions

    func testKnownCharacterNamesReturnsDistinctNamesInFirstUsedOrder() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let document = makeScriptDocument(context: context)

        ScriptBlockService.replaceAllBlocks(
            for: document,
            with: [
                (.character, "MARA"), (.dialogue, "Hi."),
                (.character, "SHERIFF COLE"), (.dialogue, "Morning."),
                (.character, "MARA"), (.dialogue, "Coffee, black.")
            ],
            context: context
        )
        try context.save()

        XCTAssertEqual(ScriptBlockService.knownCharacterNames(for: document), ["MARA", "SHERIFF COLE"])
    }

    func testKnownCharacterNamesExcludesBlankCharacterBlocks() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let document = makeScriptDocument(context: context)

        ScriptBlockService.replaceAllBlocks(for: document, with: [(.character, "")], context: context)
        try context.save()

        XCTAssertTrue(ScriptBlockService.knownCharacterNames(for: document).isEmpty)
    }

    func testSceneHeadingSuggestionsIncludesStandardPrefixesAndPreviouslyUsedHeadings() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let document = makeScriptDocument(context: context)

        ScriptBlockService.replaceAllBlocks(
            for: document,
            with: [(.sceneHeading, "INT. DINER - DAY"), (.action, "..."), (.sceneHeading, "EXT. DOCKS - NIGHT")],
            context: context
        )
        try context.save()

        let suggestions = ScriptBlockService.sceneHeadingSuggestions(for: document)
        XCTAssertTrue(suggestions.contains("INT."))
        XCTAssertTrue(suggestions.contains("EXT."))
        XCTAssertTrue(suggestions.contains("INT./EXT."))
        XCTAssertTrue(suggestions.contains("INT. DINER - DAY"))
        XCTAssertTrue(suggestions.contains("EXT. DOCKS - NIGHT"))
    }

    func testSceneHeadingSuggestionsHasNoDuplicates() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let document = makeScriptDocument(context: context)

        ScriptBlockService.replaceAllBlocks(
            for: document,
            with: [(.sceneHeading, "INT. DINER - DAY"), (.action, "..."), (.sceneHeading, "INT. DINER - DAY")],
            context: context
        )
        try context.save()

        let suggestions = ScriptBlockService.sceneHeadingSuggestions(for: document)
        XCTAssertEqual(suggestions.filter { $0 == "INT. DINER - DAY" }.count, 1)
    }

    func testReplaceAllBlocksReplacesRatherThanAppends() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let document = makeScriptDocument(context: context)

        ScriptBlockService.replaceAllBlocks(for: document, with: [(.sceneHeading, "INT. DINER - DAY")], context: context)
        try context.save()
        XCTAssertEqual(ScriptBlockService.blocks(for: document).count, 1)

        ScriptBlockService.replaceAllBlocks(for: document, with: [(.sceneHeading, "EXT. DOCKS - NIGHT"), (.action, "The tide is out.")], context: context)
        try context.save()

        let blocks = ScriptBlockService.blocks(for: document)
        XCTAssertEqual(blocks.count, 2, "Old blocks must be removed, not accumulated")
        XCTAssertEqual(blocks.map(\.text), ["EXT. DOCKS - NIGHT", "The tide is out."])
    }

    /// Kyle (2026-08-20, real use, on a real full-length script): "you can type a full word and
    /// then the word appears a moment later." Root cause was `replaceAllBlocks` deleting and
    /// recreating *every* block on *every* keystroke — real, escalating SwiftData churn as a
    /// script gets long, even though only one paragraph actually changed. This proves the fix:
    /// editing one paragraph's text must update that block in place and leave every other block's
    /// identity completely untouched, not delete-and-recreate the whole document.
    func testReplaceAllBlocksUpdatesOnlyTheChangedBlockInPlace() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let document = makeScriptDocument(context: context)

        ScriptBlockService.replaceAllBlocks(
            for: document,
            with: [(.sceneHeading, "INT. DINER - DAY"), (.action, "A quiet morning."), (.character, "MARA")],
            context: context
        )
        try context.save()
        let originalIDs = ScriptBlockService.blocks(for: document).map(\.id)

        // Simulates typing a single character into the middle (Action) paragraph — everything
        // else in the document is byte-for-byte unchanged.
        ScriptBlockService.replaceAllBlocks(
            for: document,
            with: [(.sceneHeading, "INT. DINER - DAY"), (.action, "A quiet, misty morning."), (.character, "MARA")],
            context: context
        )
        try context.save()

        let updatedBlocks = ScriptBlockService.blocks(for: document)
        XCTAssertEqual(updatedBlocks.map(\.id), originalIDs, "Untouched paragraphs must keep their exact same identity, not be deleted and recreated")
        XCTAssertEqual(updatedBlocks.map(\.text), ["INT. DINER - DAY", "A quiet, misty morning.", "MARA"])
    }

    /// The tail-shrink case: entries.count < existing.count must delete exactly the excess blocks,
    /// still leaving the untouched leading blocks' identity alone.
    func testReplaceAllBlocksDeletesOnlyTheExcessBlocksWhenTheDocumentGetsShorter() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let document = makeScriptDocument(context: context)

        ScriptBlockService.replaceAllBlocks(
            for: document,
            with: [(.sceneHeading, "INT. DINER - DAY"), (.action, "A quiet morning."), (.character, "MARA")],
            context: context
        )
        try context.save()
        let firstBlockID = ScriptBlockService.blocks(for: document)[0].id

        ScriptBlockService.replaceAllBlocks(for: document, with: [(.sceneHeading, "INT. DINER - DAY")], context: context)
        try context.save()

        let remaining = ScriptBlockService.blocks(for: document)
        XCTAssertEqual(remaining.map(\.id), [firstBlockID])
        XCTAssertEqual(remaining.map(\.text), ["INT. DINER - DAY"])
    }

    // MARK: - (CONT'D) continuation rule

    func testShouldMarkContinuedWhenSameCharacterResumesAfterOnlyAction() {
        let preceding: [(type: ScriptBlockService.ScriptElementType, text: String)] = [
            (.character, "MARA"), (.dialogue, "Coffee, black."), (.action, "She glances at the door.")
        ]
        XCTAssertTrue(ScriptBlockService.shouldMarkContinued(characterName: "MARA", precedingEntries: preceding))
    }

    func testShouldMarkContinuedWhenSplitByMultipleActionAndParentheticalBeats() {
        let preceding: [(type: ScriptBlockService.ScriptElementType, text: String)] = [
            (.character, "MARA"), (.dialogue, "Coffee, black."),
            (.action, "She glances at the door."), (.action, "The bell rings."),
            (.parenthetical, "beat")
        ]
        XCTAssertTrue(ScriptBlockService.shouldMarkContinued(characterName: "MARA", precedingEntries: preceding))
    }

    func testShouldNotMarkContinuedWhenAnotherCharacterSpokeInBetween() {
        let preceding: [(type: ScriptBlockService.ScriptElementType, text: String)] = [
            (.character, "MARA"), (.dialogue, "Coffee, black."),
            (.character, "SHERIFF COLE"), (.dialogue, "Rough morning?")
        ]
        XCTAssertFalse(ScriptBlockService.shouldMarkContinued(characterName: "MARA", precedingEntries: preceding))
    }

    func testShouldNotMarkContinuedAcrossASceneHeading() {
        let preceding: [(type: ScriptBlockService.ScriptElementType, text: String)] = [
            (.character, "MARA"), (.dialogue, "Coffee, black."),
            (.sceneHeading, "EXT. DOCKS - NIGHT"), (.action, "The tide is out.")
        ]
        XCTAssertFalse(ScriptBlockService.shouldMarkContinued(characterName: "MARA", precedingEntries: preceding))
    }

    func testShouldNotMarkContinuedAcrossATransition() {
        let preceding: [(type: ScriptBlockService.ScriptElementType, text: String)] = [
            (.character, "MARA"), (.dialogue, "Coffee, black."), (.transition, "CUT TO:")
        ]
        XCTAssertFalse(ScriptBlockService.shouldMarkContinued(characterName: "MARA", precedingEntries: preceding))
    }

    func testShouldNotMarkContinuedForACharactersFirstLineInAScene() {
        let preceding: [(type: ScriptBlockService.ScriptElementType, text: String)] = [
            (.sceneHeading, "INT. DINER - DAY"), (.action, "Quiet morning.")
        ]
        XCTAssertFalse(ScriptBlockService.shouldMarkContinued(characterName: "MARA", precedingEntries: preceding))
    }

    func testShouldMarkContinuedComparesAgainstTheBaseNameOfAnAlreadyContinuedCue() {
        let preceding: [(type: ScriptBlockService.ScriptElementType, text: String)] = [
            (.character, "MARA"), (.dialogue, "Coffee, black."),
            (.action, "Beat."), (.character, "MARA (CONT'D)"), (.dialogue, "Make it a large."),
            (.action, "She checks her phone.")
        ]
        XCTAssertTrue(ScriptBlockService.shouldMarkContinued(characterName: "MARA", precedingEntries: preceding))
    }

    func testNormalizedCharacterNameStripsContinuedSuffix() {
        XCTAssertEqual(ScriptBlockService.normalizedCharacterName("MARA (CONT'D)"), "MARA")
        XCTAssertEqual(ScriptBlockService.normalizedCharacterName("MARA"), "MARA")
    }

    func testKnownCharacterNamesTreatsAContinuedCueAsTheSameCharacter() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let document = makeScriptDocument(context: context)

        ScriptBlockService.replaceAllBlocks(
            for: document,
            with: [
                (.character, "MARA"), (.dialogue, "Coffee, black."),
                (.action, "Beat."),
                (.character, "MARA (CONT'D)"), (.dialogue, "Make it a large.")
            ],
            context: context
        )
        try context.save()

        XCTAssertEqual(ScriptBlockService.knownCharacterNames(for: document), ["MARA"])
    }

    func testDeletingTheDocumentCascadesToItsScriptBlocks() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let document = makeScriptDocument(context: context)
        ScriptBlockService.replaceAllBlocks(for: document, with: [(.sceneHeading, "INT. DINER - DAY")], context: context)
        try context.save()

        context.delete(document)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<ScriptBlockService.ScriptBlock>())
        XCTAssertTrue(remaining.isEmpty)
    }
}
