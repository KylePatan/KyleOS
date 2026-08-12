import XCTest
import SwiftData
@testable import KyleOS

final class SceneServiceTests: XCTestCase {

    private func makeActOutline(context: ModelContext) -> SceneService.Document {
        let project = ProjectService.createProject(title: "Untitled Pilot", projectType: .tvPilot, in: context)
        return DocumentService.createDocument(title: "Act Outline", type: .actOutline, in: project, context: context)
    }

    func testCreatingScenesAssignsAscendingOrderWithinTheirAct() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let document = makeActOutline(context: context)
        let act = ActService.createAct(title: "Act One", in: document, context: context)

        let sceneOne = SceneService.createScene(in: act, context: context)
        let sceneTwo = SceneService.createScene(in: act, context: context)
        try context.save()

        XCTAssertEqual(sceneOne.orderWithinAct, 0)
        XCTAssertEqual(sceneTwo.orderWithinAct, 1)
        XCTAssertEqual(SceneService.scenes(for: act).map(\.id), [sceneOne.id, sceneTwo.id])
    }

    func testUpdateSetsOnlyTheProvidedFields() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let document = makeActOutline(context: context)
        let act = ActService.createAct(title: "Act One", in: document, context: context)
        let scene = SceneService.createScene(in: act, context: context)
        try context.save()

        SceneService.update(scene, locationType: .ext, location: "DOCKS", timeOfDay: "Dawn")
        try context.save()

        XCTAssertEqual(scene.locationType, .ext)
        XCTAssertEqual(scene.location, "DOCKS")
        XCTAssertEqual(scene.timeOfDay, "Dawn")
        XCTAssertEqual(scene.purpose, "", "Untouched fields should keep their existing value")

        SceneService.update(scene, purpose: "Introduce the stranger")
        try context.save()

        XCTAssertEqual(scene.location, "DOCKS", "A later partial update must not clobber earlier fields")
        XCTAssertEqual(scene.purpose, "Introduce the stranger")
    }

    func testDeletingASceneRenumbersTheRemainingScenesInThatActContiguously() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let document = makeActOutline(context: context)
        let act = ActService.createAct(title: "Act One", in: document, context: context)
        let sceneOne = SceneService.createScene(in: act, context: context)
        let sceneTwo = SceneService.createScene(in: act, context: context)
        let sceneThree = SceneService.createScene(in: act, context: context)
        try context.save()

        SceneService.delete(sceneTwo, from: act, context: context)
        try context.save()

        XCTAssertEqual(SceneService.scenes(for: act).map(\.id), [sceneOne.id, sceneThree.id])
        XCTAssertEqual(sceneOne.orderWithinAct, 0)
        XCTAssertEqual(sceneThree.orderWithinAct, 1)
    }

    func testReorderMovingLastSceneToFirstRenumbersTheAct() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let document = makeActOutline(context: context)
        let act = ActService.createAct(title: "Act One", in: document, context: context)
        let sceneOne = SceneService.createScene(in: act, context: context)
        let sceneTwo = SceneService.createScene(in: act, context: context)
        let sceneThree = SceneService.createScene(in: act, context: context)
        try context.save()

        SceneService.reorder(within: act, movingFromOffsets: IndexSet(integer: 2), toOffset: 0)
        try context.save()

        XCTAssertEqual(SceneService.scenes(for: act).map(\.id), [sceneThree.id, sceneOne.id, sceneTwo.id])
    }

    func testMovingASceneBetweenActsUpdatesBothActsOrdering() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let document = makeActOutline(context: context)
        let actOne = ActService.createAct(title: "Act One", in: document, context: context)
        let actTwo = ActService.createAct(title: "Act Two", in: document, context: context)
        let sceneOne = SceneService.createScene(in: actOne, context: context)
        let sceneTwo = SceneService.createScene(in: actOne, context: context)
        try context.save()

        SceneService.move(sceneOne, to: actTwo, context: context)
        try context.save()

        XCTAssertEqual(SceneService.scenes(for: actOne).map(\.id), [sceneTwo.id])
        XCTAssertEqual(sceneTwo.orderWithinAct, 0, "actOne should renumber contiguously after losing a scene")
        XCTAssertEqual(SceneService.scenes(for: actTwo).map(\.id), [sceneOne.id])
        XCTAssertEqual(sceneOne.act?.id, actTwo.id)
    }

    func testNumberedScenesAreSequentialAcrossTheWholeOutlineNotPerAct() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let document = makeActOutline(context: context)
        let actOne = ActService.createAct(title: "Act One", in: document, context: context)
        let actTwo = ActService.createAct(title: "Act Two", in: document, context: context)
        let sceneOneA = SceneService.createScene(in: actOne, context: context)
        let sceneOneB = SceneService.createScene(in: actOne, context: context)
        let sceneTwoA = SceneService.createScene(in: actTwo, context: context)
        try context.save()

        let numbered = SceneService.numberedScenes(for: document)

        XCTAssertEqual(numbered.map(\.scene.id), [sceneOneA.id, sceneOneB.id, sceneTwoA.id])
        XCTAssertEqual(numbered.map(\.number), [1, 2, 3])
    }

    func testDeletingAnActCascadesToItsScenes() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let document = makeActOutline(context: context)
        let act = ActService.createAct(title: "Act One", in: document, context: context)
        SceneService.createScene(in: act, context: context)
        try context.save()

        context.delete(act)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<SceneService.Scene>())
        XCTAssertTrue(remaining.isEmpty)
    }
}
