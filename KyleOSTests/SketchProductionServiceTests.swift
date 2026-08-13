import XCTest
import SwiftData
@testable import KyleOS

final class SketchProductionServiceTests: XCTestCase {

    private func makeFinishedSketch(title: String = "Airport Sketch", context: ModelContext) -> ProjectService.Project {
        ProjectService.createProject(title: title, projectType: .sketch, status: .finished, in: context)
    }

    func testStatusDefaultsToFilmingNotScheduledWithoutCreatingARecord() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = makeFinishedSketch(context: context)
        try context.save()

        XCTAssertEqual(SketchProductionService.status(for: project), .filmingNotScheduled)
        XCTAssertNil(project.sketchProduction, "Merely reading status must not create a SketchProduction row")
    }

    func testChangeStatusCreatesARecordOnFirstCall() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = makeFinishedSketch(context: context)
        try context.save()

        SketchProductionService.changeStatus(for: project, to: .filmingScheduled, context: context)
        try context.save()

        XCTAssertEqual(SketchProductionService.status(for: project), .filmingScheduled)
        XCTAssertNotNil(project.sketchProduction)
    }

    func testChangeStatusReusesTheExistingRecordOnSubsequentCalls() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = makeFinishedSketch(context: context)
        try context.save()

        SketchProductionService.changeStatus(for: project, to: .filmingScheduled, context: context)
        try context.save()
        let firstID = project.sketchProduction?.id
        SketchProductionService.changeStatus(for: project, to: .filmed, context: context)
        try context.save()

        XCTAssertEqual(project.sketchProduction?.id, firstID)
        XCTAssertEqual(SketchProductionService.status(for: project), .filmed)
    }

    func testSetPostDatePersists() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = makeFinishedSketch(context: context)
        try context.save()
        let postDate = Date(timeIntervalSince1970: 1_700_000_000)

        SketchProductionService.setPostDate(for: project, date: postDate, context: context)
        try context.save()

        XCTAssertEqual(SketchProductionService.postDate(for: project), postDate)
    }

    func testFinishedSketchProjectsExcludesUnfinishedAndNonSketchAndArchived() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let finishedSketch = makeFinishedSketch(title: "Finished Sketch", context: context)
        ProjectService.createProject(title: "In-Progress Sketch", projectType: .sketch, status: .active, in: context)
        ProjectService.createProject(title: "Finished Screenplay", projectType: .screenplay, status: .finished, in: context)
        let archivedSketch = makeFinishedSketch(title: "Archived Sketch", context: context)
        ProjectService.archive(archivedSketch)
        try context.save()

        let results = SketchProductionService.finishedSketchProjects(in: context)

        XCTAssertEqual(results.map(\.id), [finishedSketch.id])
    }

    func testFinishedSketchProjectsInStatusFiltersByProductionStatus() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let scheduled = makeFinishedSketch(title: "Scheduled Sketch", context: context)
        let notScheduled = makeFinishedSketch(title: "Not Scheduled Sketch", context: context)
        try context.save()
        SketchProductionService.changeStatus(for: scheduled, to: .filmingScheduled, context: context)
        try context.save()

        let scheduledResults = SketchProductionService.finishedSketchProjects(inStatus: .filmingScheduled, in: context)
        let notScheduledResults = SketchProductionService.finishedSketchProjects(inStatus: .filmingNotScheduled, in: context)

        XCTAssertEqual(scheduledResults.map(\.id), [scheduled.id])
        XCTAssertEqual(notScheduledResults.map(\.id), [notScheduled.id])
    }

    func testDeletingProjectCascadeDeletesItsSketchProduction() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = makeFinishedSketch(context: context)
        try context.save()
        SketchProductionService.changeStatus(for: project, to: .filmingScheduled, context: context)
        try context.save()
        let productionID = try XCTUnwrap(project.sketchProduction?.id)

        context.delete(project)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<SketchProductionService.SketchProduction>())
        XCTAssertFalse(remaining.contains { $0.id == productionID })
    }
}
