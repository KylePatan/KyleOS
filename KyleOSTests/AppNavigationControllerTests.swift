import XCTest
import SwiftData
@testable import KyleOS

/// Kyle (2026-08-20, real use): "short films and sketches that are finished scripts should be
/// sent to the sketches module." Covers `DeepLinkTarget.forWorkItem`'s routing specifically for
/// this — clicking a Home card for a Short Film's work item must land on Sketches once the film
/// is finished (same as a Sketch already did), and on Writing while it's still being written.
final class AppNavigationControllerTests: XCTestCase {
    func testWorkItemForAFinishedShortFilmRoutesToSketches() throws {
        let context = ModelContext(PersistenceController.makeInMemoryContainer())
        let project = ProjectService.createProject(title: "Airport Chase", projectType: .shortFilm, status: .finished, in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Editing", workspace: .sketches, workTypeName: "Editing", in: project, context: context
        )
        try context.save()

        XCTAssertEqual(DeepLinkTarget.forWorkItem(workItem), .sketchProject(project.persistentModelID))
    }

    func testWorkItemForAnInProgressShortFilmRoutesToWriting() throws {
        let context = ModelContext(PersistenceController.makeInMemoryContainer())
        let project = ProjectService.createProject(title: "Airport Chase", projectType: .shortFilm, status: .active, in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        try context.save()

        XCTAssertEqual(DeepLinkTarget.forWorkItem(workItem), .writingProject(project.persistentModelID))
    }

    func testWorkItemForAFinishedSketchStillRoutesToSketches() throws {
        let context = ModelContext(PersistenceController.makeInMemoryContainer())
        let project = ProjectService.createProject(title: "Airport Sketch", projectType: .sketch, status: .finished, in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Editing", workspace: .sketches, workTypeName: "Editing", in: project, context: context
        )
        try context.save()

        XCTAssertEqual(DeepLinkTarget.forWorkItem(workItem), .sketchProject(project.persistentModelID))
    }
}
