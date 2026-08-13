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

    // MARK: - Film Scheduling (PRD §9.3)

    func testScheduleFilmCreatesLinkedStandUpGigStyleCalendarEvent() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = makeFinishedSketch(context: context)
        try context.save()
        let callTime = Date(timeIntervalSince1970: 1_700_000_000)
        let wrapTime = callTime.addingTimeInterval(8 * 3600)

        let shoot = SketchProductionService.scheduleFilm(for: project, callTime: callTime, estimatedWrapTime: wrapTime, context: context)
        try context.save()

        let event = try XCTUnwrap(shoot.calendarEvent)
        XCTAssertEqual(event.eventType, .filmShoot)
        XCTAssertEqual(event.startAt, callTime)
        XCTAssertEqual(event.endAt, wrapTime)
        XCTAssertEqual(event.filmShoot?.id, shoot.id)
    }

    func testScheduleFilmAdvancesStatusFromFilmingNotScheduledToFilmingScheduled() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = makeFinishedSketch(context: context)
        try context.save()

        SketchProductionService.scheduleFilm(for: project, callTime: .now, estimatedWrapTime: .now.addingTimeInterval(3600), context: context)
        try context.save()

        XCTAssertEqual(SketchProductionService.status(for: project), .filmingScheduled)
    }

    func testScheduleFilmDoesNotRegressALaterStatus() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = makeFinishedSketch(context: context)
        try context.save()
        SketchProductionService.changeStatus(for: project, to: .filmed, context: context)
        try context.save()

        SketchProductionService.scheduleFilm(for: project, callTime: .now, estimatedWrapTime: .now.addingTimeInterval(3600), context: context)
        try context.save()

        XCTAssertEqual(SketchProductionService.status(for: project), .filmed, "Rescheduling an already-filmed shoot must not move status backward")
    }

    func testScheduleFilmCalledTwiceUpdatesTheSameShootRatherThanCreatingASecondOne() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = makeFinishedSketch(context: context)
        try context.save()
        let firstCallTime = Date(timeIntervalSince1970: 1_700_000_000)
        SketchProductionService.scheduleFilm(for: project, callTime: firstCallTime, estimatedWrapTime: firstCallTime.addingTimeInterval(3600), context: context)
        try context.save()
        let firstShootID = project.sketchProduction?.filmShoot?.id

        let secondCallTime = Date(timeIntervalSince1970: 1_800_000_000)
        SketchProductionService.scheduleFilm(for: project, callTime: secondCallTime, estimatedWrapTime: secondCallTime.addingTimeInterval(3600), context: context)
        try context.save()

        XCTAssertEqual(project.sketchProduction?.filmShoot?.id, firstShootID)
        XCTAssertEqual(project.sketchProduction?.filmShoot?.callTime, secondCallTime)
        XCTAssertEqual(project.sketchProduction?.filmShoot?.calendarEvent?.startAt, secondCallTime)
    }

    func testUpdateLocationAndCastCrewMakeTheEventAHardCommitment() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = makeFinishedSketch(context: context)
        try context.save()
        let shoot = SketchProductionService.scheduleFilm(for: project, callTime: .now, estimatedWrapTime: .now.addingTimeInterval(3600), context: context)
        try context.save()
        XCTAssertFalse(shoot.calendarEvent?.isHardCommitment ?? true, "No cast/crew/location yet — should not be a hard commitment")

        SketchProductionService.updateLocation(shoot, location: "123 Main St Studio", address: "123 Main St", context: context)
        try context.save()

        XCTAssertTrue(shoot.calendarEvent?.isHardCommitment ?? false)
        XCTAssertEqual(shoot.calendarEvent?.location, "123 Main St Studio")
    }

    func testUpdateCastAndCrewMakesTheEventAHardCommitment() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = makeFinishedSketch(context: context)
        try context.save()
        let shoot = SketchProductionService.scheduleFilm(for: project, callTime: .now, estimatedWrapTime: .now.addingTimeInterval(3600), context: context)
        try context.save()

        SketchProductionService.updateCastAndCrew(shoot, cast: "Jane Doe", crew: "John Smith (DP)", context: context)
        try context.save()

        XCTAssertEqual(shoot.cast, "Jane Doe")
        XCTAssertEqual(shoot.crew, "John Smith (DP)")
        XCTAssertTrue(shoot.calendarEvent?.isHardCommitment ?? false)
    }

    func testUpdateLogisticsPersistsAllFieldsWithoutTouchingTheCalendarEvent() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = makeFinishedSketch(context: context)
        try context.save()
        let shoot = SketchProductionService.scheduleFilm(for: project, callTime: .now, estimatedWrapTime: .now.addingTimeInterval(3600), context: context)
        try context.save()
        let originalHardCommitment = shoot.calendarEvent?.isHardCommitment

        SketchProductionService.updateLogistics(
            shoot,
            wardrobe: "Casual",
            props: "Coffee cup",
            equipmentNotes: "Bring the boom mic",
            parkingAccessInstructions: "Street parking on Main St",
            generalNotes: "Golden hour scenes first"
        )
        try context.save()

        XCTAssertEqual(shoot.wardrobe, "Casual")
        XCTAssertEqual(shoot.props, "Coffee cup")
        XCTAssertEqual(shoot.equipmentNotes, "Bring the boom mic")
        XCTAssertEqual(shoot.parkingAccessInstructions, "Street parking on Main St")
        XCTAssertEqual(shoot.generalNotes, "Golden hour scenes first")
        XCTAssertEqual(shoot.calendarEvent?.isHardCommitment, originalHardCommitment, "Logistics fields must not affect the hard-commitment calculation")
    }

    func testDeletingProjectCascadeDeletesItsFilmShootAndCalendarEvent() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = makeFinishedSketch(context: context)
        try context.save()
        let shoot = SketchProductionService.scheduleFilm(for: project, callTime: .now, estimatedWrapTime: .now.addingTimeInterval(3600), context: context)
        try context.save()
        let shootID = shoot.id
        let eventID = try XCTUnwrap(shoot.calendarEvent?.id)

        context.delete(project)
        try context.save()

        let remainingShoots = try context.fetch(FetchDescriptor<SketchProductionService.FilmShoot>())
        XCTAssertFalse(remainingShoots.contains { $0.id == shootID })
        let remainingEvents = try context.fetch(FetchDescriptor<CalendarEventService.CalendarEvent>())
        XCTAssertFalse(remainingEvents.contains { $0.id == eventID })
    }
}
