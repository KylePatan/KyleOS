import XCTest
import SwiftData
@testable import KyleOS

final class ActServiceTests: XCTestCase {

    private func makeActOutlineDocument(context: ModelContext) -> ActService.Document {
        let project = ProjectService.createProject(title: "Untitled Pilot", projectType: .tvPilot, in: context)
        return DocumentService.createDocument(title: "Act Outline", type: .actOutline, in: project, context: context)
    }

    func testCreatingActsAssignsAscendingOrder() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let document = makeActOutlineDocument(context: context)

        let actOne = ActService.createAct(title: "Act One", in: document, context: context)
        let actTwo = ActService.createAct(title: "Act Two", in: document, context: context)
        try context.save()

        XCTAssertEqual(actOne.order, 0)
        XCTAssertEqual(actTwo.order, 1)
        XCTAssertEqual(ActService.acts(for: document).map(\.id), [actOne.id, actTwo.id])
    }

    func testKyleOSDoesNotForceExactlyThreeActs() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let document = makeActOutlineDocument(context: context)

        ActService.createAct(title: "Cold Open", in: document, context: context)
        ActService.createAct(title: "Act One", in: document, context: context)
        try context.save()

        XCTAssertEqual(ActService.acts(for: document).count, 2, "Two acts should be perfectly valid, not forced to three")
    }

    func testRenameAndUpdateSynopsisPersist() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let document = makeActOutlineDocument(context: context)
        let act = ActService.createAct(title: "Working Title", in: document, context: context)
        try context.save()

        ActService.rename(act, to: "The Setup")
        ActService.updateSynopsis(act, synopsis: "Our hero discovers the inciting incident.")
        try context.save()

        XCTAssertEqual(act.title, "The Setup")
        XCTAssertEqual(act.synopsis, "Our hero discovers the inciting incident.")
    }

    func testReorderMovingLastActToFirstRenumbersEveryone() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let document = makeActOutlineDocument(context: context)
        let actOne = ActService.createAct(title: "Act One", in: document, context: context)
        let actTwo = ActService.createAct(title: "Act Two", in: document, context: context)
        let actThree = ActService.createAct(title: "Act Three", in: document, context: context)
        try context.save()

        ActService.reorder(document, movingFromOffsets: IndexSet(integer: 2), toOffset: 0)
        try context.save()

        XCTAssertEqual(ActService.acts(for: document).map(\.id), [actThree.id, actOne.id, actTwo.id])
        XCTAssertEqual(actThree.order, 0)
        XCTAssertEqual(actOne.order, 1)
        XCTAssertEqual(actTwo.order, 2)
    }

    func testDeletingAnActRenumbersTheRemainingActsContiguously() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let document = makeActOutlineDocument(context: context)
        let actOne = ActService.createAct(title: "Act One", in: document, context: context)
        let actTwo = ActService.createAct(title: "Act Two", in: document, context: context)
        let actThree = ActService.createAct(title: "Act Three", in: document, context: context)
        try context.save()

        ActService.delete(actTwo, from: document, context: context)
        try context.save()

        XCTAssertEqual(ActService.acts(for: document).map(\.id), [actOne.id, actThree.id])
        XCTAssertEqual(actOne.order, 0)
        XCTAssertEqual(actThree.order, 1, "Order should stay contiguous (0,1,...) after a deletion, not leave a gap")
    }

    func testDeletingTheDocumentCascadesToItsActs() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let document = makeActOutlineDocument(context: context)
        ActService.createAct(title: "Act One", in: document, context: context)
        try context.save()

        context.delete(document)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<ActService.Act>())
        XCTAssertTrue(remaining.isEmpty)
    }
}
