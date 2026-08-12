import XCTest
import SwiftData
@testable import KyleOS

final class DraftServiceTests: XCTestCase {

    func testNewDocumentHasNoFrozenDraftsAndDisplaysFirstDraft() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let document = DocumentService.createDocument(title: "Chapter One", type: .prose, in: project, context: context)
        try context.save()

        XCTAssertEqual(document.displayDraftLabel, "First Draft")
        XCTAssertTrue(DraftService.drafts(for: document).isEmpty)
    }

    func testStartNewDraftFreezesCurrentContentAndAdvancesTheLabel() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let document = DocumentService.createDocument(title: "Chapter One", type: .prose, in: project, context: context)
        DocumentService.updateContent(document, content: "It was a dark and stormy night.")
        try context.save()

        let frozen = DraftService.startNewDraft(for: document, context: context)
        try context.save()

        XCTAssertEqual(frozen.label, "First Draft")
        XCTAssertEqual(frozen.content, "It was a dark and stormy night.")
        XCTAssertEqual(document.displayDraftLabel, "Second Draft")
        XCTAssertEqual(document.content, "It was a dark and stormy night.", "Starting a new draft continues from where the last one left off, it doesn't blank the page")
    }

    func testStartingMultipleDraftsUsesTheOrdinalSequence() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let document = DocumentService.createDocument(title: "Chapter One", type: .prose, in: project, context: context)
        try context.save()

        DraftService.startNewDraft(for: document, context: context)
        DraftService.startNewDraft(for: document, context: context)
        try context.save()

        XCTAssertEqual(document.displayDraftLabel, "Third Draft")
        XCTAssertEqual(DraftService.drafts(for: document).map(\.label), ["Second Draft", "First Draft"], "Most recent frozen draft first")
    }

    func testRestoreCopiesDraftContentAndNeverDiscardsTheCurrentLiveContentUnfrozen() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let document = DocumentService.createDocument(title: "Chapter One", type: .prose, in: project, context: context)
        DocumentService.updateContent(document, content: "Version one.")
        try context.save()

        let firstDraft = DraftService.startNewDraft(for: document, context: context)
        DocumentService.updateContent(document, content: "Version two, a total rewrite.")
        try context.save()

        DraftService.restore(firstDraft, into: document, context: context)
        try context.save()

        XCTAssertEqual(document.content, "Version one.", "Live content now matches the restored draft")
        // Data safety (CLAUDE.md §5): "Version two" must not have been silently discarded — it
        // should have been auto-frozen as its own draft before the restore overwrote it.
        let labels = DraftService.drafts(for: document).map { ($0.label, $0.content) }
        XCTAssertTrue(labels.contains { $0.0 == "Second Draft" && $0.1 == "Version two, a total rewrite." })
        XCTAssertTrue(labels.contains { $0.0 == "First Draft" && $0.1 == "Version one." })
    }

    func testSuggestedLabelFallsBackToNumberedDraftsPastTheOrdinalList() throws {
        XCTAssertEqual(DraftService.suggestedLabel(afterFrozenDraftCount: 0), "First Draft")
        XCTAssertEqual(DraftService.suggestedLabel(afterFrozenDraftCount: 9), "Tenth Draft")
        XCTAssertEqual(DraftService.suggestedLabel(afterFrozenDraftCount: 10), "Draft 11")
    }
}
