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

    /// Kyle (2026-08-20, real use): "short films and sketches that are finished scripts should be
    /// sent to the sketches module - because they require the same sort of process of filming and
    /// posting." A finished Short Film must join a finished Sketch on the board; an in-progress
    /// Short Film (still being written) must not — it only graduates once finished, same gate as
    /// Sketch itself always had.
    func testFinishedSketchProjectsIncludesFinishedShortFilmsAlongsideSketches() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let finishedSketch = makeFinishedSketch(title: "Finished Sketch", context: context)
        let finishedShortFilm = ProjectService.createProject(title: "Finished Short Film", projectType: .shortFilm, status: .finished, in: context)
        ProjectService.createProject(title: "In-Progress Short Film", projectType: .shortFilm, status: .active, in: context)
        try context.save()

        let results = SketchProductionService.finishedSketchProjects(in: context)

        XCTAssertEqual(Set(results.map(\.id)), Set([finishedSketch.id, finishedShortFilm.id]))
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

    // MARK: - Call Sheet (PRD §9.4)

    private func makeScheduledShoot(context: ModelContext) -> (ProjectService.Project, SketchProductionService.FilmShoot) {
        let project = makeFinishedSketch(context: context)
        let shoot = SketchProductionService.scheduleFilm(for: project, callTime: .now, estimatedWrapTime: .now.addingTimeInterval(8 * 3600), context: context)
        SketchProductionService.updateLocation(shoot, location: "Downtown Studio", address: "123 Main St", context: context)
        SketchProductionService.updateCastAndCrew(shoot, cast: "Jane Doe", crew: "Alex Kim (DP)", context: context)
        return (project, shoot)
    }

    func testGenerateCallSheetSeedsFieldsFromFilmShoot() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let (project, shoot) = makeScheduledShoot(context: context)
        try context.save()

        let callSheet = SketchProductionService.generateCallSheet(for: shoot, projectTitle: project.title, context: context)
        try context.save()

        XCTAssertEqual(callSheet.projectTitle, project.title)
        XCTAssertEqual(callSheet.callTime, shoot.callTime)
        XCTAssertEqual(callSheet.wrapTime, shoot.estimatedWrapTime)
        XCTAssertEqual(callSheet.location, "Downtown Studio")
        XCTAssertEqual(callSheet.address, "123 Main St")
        XCTAssertEqual(callSheet.castAndCharacters, "Jane Doe")
        XCTAssertEqual(callSheet.crewAndRoles, "Alex Kim (DP)")
        XCTAssertEqual(callSheet.contactInformation, "", "Fields with no FilmShoot counterpart must start empty")
        XCTAssertEqual(callSheet.sceneNotes, "")
    }

    func testGenerateCallSheetReusesTheExistingOneOnSubsequentCalls() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let (project, shoot) = makeScheduledShoot(context: context)
        try context.save()
        let first = SketchProductionService.generateCallSheet(for: shoot, projectTitle: project.title, context: context)
        try context.save()

        let second = SketchProductionService.generateCallSheet(for: shoot, projectTitle: project.title, context: context)

        XCTAssertEqual(first.id, second.id)
    }

    func testEditingCallSheetDoesNotWriteBackToFilmShoot() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let (project, shoot) = makeScheduledShoot(context: context)
        try context.save()
        let callSheet = SketchProductionService.generateCallSheet(for: shoot, projectTitle: project.title, context: context)
        try context.save()

        SketchProductionService.updateCallSheetSchedule(callSheet, callTime: callSheet.callTime, wrapTime: callSheet.wrapTime, location: "Different Location", address: callSheet.address)
        try context.save()

        XCTAssertEqual(callSheet.location, "Different Location")
        XCTAssertEqual(shoot.location, "Downtown Studio", "Editing the Call Sheet must not write back to the FilmShoot")
    }

    func testReschedulingFilmShootDoesNotRewriteAnAlreadyGeneratedCallSheet() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let (project, shoot) = makeScheduledShoot(context: context)
        try context.save()
        let callSheet = SketchProductionService.generateCallSheet(for: shoot, projectTitle: project.title, context: context)
        try context.save()

        SketchProductionService.updateLocation(shoot, location: "New Location", address: shoot.address, context: context)
        try context.save()

        XCTAssertEqual(shoot.location, "New Location")
        XCTAssertEqual(callSheet.location, "Downtown Studio", "Rescheduling FilmShoot must not silently rewrite an already-generated Call Sheet")
    }

    func testUpdateCallSheetPeoplePersists() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let (project, shoot) = makeScheduledShoot(context: context)
        try context.save()
        let callSheet = SketchProductionService.generateCallSheet(for: shoot, projectTitle: project.title, context: context)
        try context.save()

        SketchProductionService.updateCallSheetPeople(callSheet, castAndCharacters: "Jane Doe as The Traveler", crewAndRoles: "Alex Kim (DP)", contactInformation: "Producer: 555-1234")
        try context.save()

        XCTAssertEqual(callSheet.castAndCharacters, "Jane Doe as The Traveler")
        XCTAssertEqual(callSheet.contactInformation, "Producer: 555-1234")
    }

    func testUpdateCallSheetLogisticsPersists() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let (project, shoot) = makeScheduledShoot(context: context)
        try context.save()
        let callSheet = SketchProductionService.generateCallSheet(for: shoot, projectTitle: project.title, context: context)
        try context.save()

        SketchProductionService.updateCallSheetLogistics(callSheet, wardrobe: "Casual", props: "Coffee cup", equipment: "Boom mic", parkingAccess: "Street parking")
        try context.save()

        XCTAssertEqual(callSheet.wardrobe, "Casual")
        XCTAssertEqual(callSheet.equipment, "Boom mic")
    }

    func testUpdateCallSheetNotesPersists() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let (project, shoot) = makeScheduledShoot(context: context)
        try context.save()
        let callSheet = SketchProductionService.generateCallSheet(for: shoot, projectTitle: project.title, context: context)
        try context.save()

        SketchProductionService.updateCallSheetNotes(callSheet, sceneNotes: "Scenes 1-3", additionalNotes: "Golden hour first")
        try context.save()

        XCTAssertEqual(callSheet.sceneNotes, "Scenes 1-3")
        XCTAssertEqual(callSheet.additionalNotes, "Golden hour first")
    }

    func testDeletingFilmShootCascadeDeletesItsCallSheet() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let (project, shoot) = makeScheduledShoot(context: context)
        try context.save()
        let callSheet = SketchProductionService.generateCallSheet(for: shoot, projectTitle: project.title, context: context)
        try context.save()
        let callSheetID = callSheet.id

        context.delete(project)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<SketchProductionService.CallSheet>())
        XCTAssertFalse(remaining.contains { $0.id == callSheetID })
    }

    // MARK: - Reels (Kyle, 2026-08-20: "a really quick reel/sketch that doesn't have a script")

    func testMarkAsReelCreatesALinkedSourcelessClip() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Airport Bit", projectType: .sketch, in: context)
        try context.save()
        XCTAssertFalse(SketchProductionService.isReel(project))

        let clip = SketchProductionService.markAsReel(project, context: context)
        try context.save()

        XCTAssertTrue(SketchProductionService.isReel(project))
        XCTAssertEqual(project.reelClip?.id, clip.id)
        XCTAssertEqual(clip.sketchProject?.id, project.id)
        XCTAssertNil(clip.source, "A Reel Clip has no recording-session Source")
        XCTAssertEqual(clip.title, "Airport Bit")
    }

    func testMarkAsReelCalledTwiceReusesTheSameClipRatherThanCreatingASecondOne() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Airport Bit", projectType: .sketch, in: context)
        try context.save()

        let first = SketchProductionService.markAsReel(project, context: context)
        try context.save()
        let second = SketchProductionService.markAsReel(project, context: context)
        try context.save()

        XCTAssertEqual(first.id, second.id)
        let allClips = try context.fetch(FetchDescriptor<ClipService.Clip>())
        XCTAssertEqual(allClips.count, 1)
    }

    /// The whole point: a Reel's Clip must show up and behave exactly like any other Clip on the
    /// real board Kyle actually uses.
    func testReelClipAppearsOnTheNormalClipsBoardAndCanProgressThroughEditing() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Airport Bit", projectType: .sketch, in: context)
        try context.save()
        let clip = SketchProductionService.markAsReel(project, context: context)
        try context.save()

        XCTAssertEqual(ClipService.boardLane(for: clip.status), .toIsolate)
        ClipService.changeStatus(clip, to: .currentlyEditing, context: context)
        try context.save()
        XCTAssertEqual(ClipService.boardLane(for: clip.status), .editing)
    }

    /// Unmarking must never destroy real editing/posting work already logged against the Clip —
    /// same "outlives its origin" reasoning as every other Clip cross-reference in this codebase.
    func testUnmarkAsReelKeepsTheClipIntact() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Airport Bit", projectType: .sketch, in: context)
        try context.save()
        let clip = SketchProductionService.markAsReel(project, context: context)
        ClipService.changeStatus(clip, to: .currentlyEditing, context: context)
        try context.save()

        SketchProductionService.unmarkAsReel(project)
        try context.save()

        XCTAssertFalse(SketchProductionService.isReel(project))
        let survivingClips = try context.fetch(FetchDescriptor<ClipService.Clip>())
        XCTAssertEqual(survivingClips.map(\.id), [clip.id], "The Clip and its editing progress must survive being unmarked")
    }

    func testDeletingTheProjectNullifiesTheClipInsteadOfDeletingIt() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Airport Bit", projectType: .sketch, in: context)
        try context.save()
        let clip = SketchProductionService.markAsReel(project, context: context)
        let clipID = clip.id
        try context.save()

        context.delete(project)
        try context.save()

        let survivingClips = try context.fetch(FetchDescriptor<ClipService.Clip>())
        XCTAssertEqual(survivingClips.map(\.id), [clipID], "Deleting the Project must not delete its Reel Clip")
        XCTAssertNil(survivingClips.first?.sketchProject, "The reference should be nullified, not left dangling")
    }
}
