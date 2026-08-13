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

    func testSuggestedNextTypeAfterDialogueIsCharacter() {
        XCTAssertEqual(ScriptBlockService.suggestedNextType(afterEnterFrom: .dialogue), .character)
    }

    func testSuggestedNextTypeAfterParentheticalIsDialogue() {
        XCTAssertEqual(ScriptBlockService.suggestedNextType(afterEnterFrom: .parenthetical), .dialogue)
    }

    func testSuggestedNextTypeAfterTransitionIsAction() {
        XCTAssertEqual(ScriptBlockService.suggestedNextType(afterEnterFrom: .transition), .action)
    }

    // MARK: - Tab-cycle (manual override fallback)

    func testTabCycleVisitsAllSixTypesAndReturnsToStart() {
        var type = ScriptBlockService.ScriptElementType.sceneHeading
        var seen: [ScriptBlockService.ScriptElementType] = [type]
        for _ in 0..<5 {
            type = ScriptBlockService.nextTypeInCycle(after: type)
            seen.append(type)
        }
        XCTAssertEqual(Set(seen), Set(ScriptBlockService.ScriptElementType.allCases), "Every type should be reachable")
        XCTAssertEqual(ScriptBlockService.nextTypeInCycle(after: type), .sceneHeading, "Cycle should be closed")
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
