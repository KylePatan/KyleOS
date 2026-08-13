import XCTest
import SwiftData
@testable import KyleOS

final class DeadlinePersistenceTests: XCTestCase {

    func testSettingAProjectDeadlinePersists() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let dueDate = Date(timeIntervalSinceNow: 60 * 60 * 24 * 30)
        let deadline = DeadlineService.setDeadline(
            for: project, label: "Submission Deadline", dueAt: dueDate, context: context
        )
        try context.save()

        XCTAssertEqual(project.deadline?.id, deadline.id)
        XCTAssertEqual(project.deadline?.label, "Submission Deadline")
        XCTAssertTrue(deadline.isHard)
        XCTAssertFalse(deadline.isConfirmed)
    }

    func testSettingAWorkItemDeadlinePersists() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let dueDate = Date(timeIntervalSinceNow: 60 * 60 * 24 * 7)
        let deadline = DeadlineService.setDeadline(
            for: workItem, label: "Draft Due", dueAt: dueDate, isHard: false, context: context
        )
        try context.save()

        XCTAssertEqual(workItem.deadline?.id, deadline.id)
        XCTAssertFalse(deadline.isHard)
    }

    func testConfirmAndRescheduleUpdateState() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let deadline = DeadlineService.setDeadline(
            for: project, label: "Submission Deadline", dueAt: .now, context: context
        )
        try context.save()

        DeadlineService.confirm(deadline)
        let newDate = Date(timeIntervalSinceNow: 60 * 60 * 24 * 60)
        DeadlineService.reschedule(deadline, to: newDate)
        try context.save()

        XCTAssertTrue(deadline.isConfirmed)
        XCTAssertEqual(deadline.dueAt.timeIntervalSince1970, newDate.timeIntervalSince1970, accuracy: 1)
    }

    func testDeletingProjectCascadesToItsDeadline() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        DeadlineService.setDeadline(for: project, label: "Submission Deadline", dueAt: .now, context: context)
        try context.save()

        context.delete(project)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<DeadlineService.Deadline>())
        XCTAssertEqual(remaining.count, 0, "Deleting a Project must cascade-delete its Deadline")
    }

    func testHardDeadlineAutomaticallyAppearsOnCalendar() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let dueDate = Date(timeIntervalSinceNow: 60 * 60 * 24 * 30)
        let deadline = DeadlineService.setDeadline(
            for: project, label: "Submission Deadline", dueAt: dueDate, isHard: true, context: context
        )
        try context.save()

        XCTAssertEqual(deadline.calendarEvents.count, 1)
        let event = try XCTUnwrap(deadline.calendarEvents.first)
        XCTAssertEqual(event.eventType, .hardDeadline)
        XCTAssertTrue(event.isHardCommitment)
        XCTAssertEqual(event.startAt.timeIntervalSince1970, dueDate.timeIntervalSince1970, accuracy: 1)
    }

    func testSoftDeadlineDoesNotCreateACalendarEvent() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let deadline = DeadlineService.setDeadline(
            for: project, label: "Soft Target", dueAt: .now, isHard: false, context: context
        )
        try context.save()

        XCTAssertTrue(deadline.calendarEvents.isEmpty)
    }

    func testReschedulingADeadlineMovesItsLinkedCalendarEventEvenIfLocked() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let deadline = DeadlineService.setDeadline(for: project, label: "Submission Deadline", dueAt: .now, context: context)
        try context.save()
        let event = try XCTUnwrap(deadline.calendarEvents.first)
        CalendarEventService.setLocked(event, true)

        let newDate = Date(timeIntervalSinceNow: 60 * 60 * 24 * 60)
        DeadlineService.reschedule(deadline, to: newDate)
        try context.save()

        XCTAssertEqual(event.startAt.timeIntervalSince1970, newDate.timeIntervalSince1970, accuracy: 1, "A deliberate Deadline reschedule must move its Calendar Event even when locked")
    }

    func testConfirmingADeadlineLocksItsCalendarEvent() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let deadline = DeadlineService.setDeadline(for: project, label: "Submission Deadline", dueAt: .now, context: context)
        try context.save()
        let event = try XCTUnwrap(deadline.calendarEvents.first)
        XCTAssertFalse(event.isLocked)

        DeadlineService.confirm(deadline)
        try context.save()
        XCTAssertTrue(event.isLocked)

        DeadlineService.unconfirm(deadline)
        try context.save()
        XCTAssertFalse(event.isLocked)
    }

    func testDeletingADeadlineOrphansRatherThanDeletesItsCalendarEvent() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let deadline = DeadlineService.setDeadline(for: workItem, label: "Draft Due", dueAt: .now, context: context)
        try context.save()
        let eventID = try XCTUnwrap(deadline.calendarEvents.first).id

        context.delete(deadline)
        try context.save()

        let survivingEvents = try context.fetch(FetchDescriptor<CalendarEventService.CalendarEvent>())
        let survivor = survivingEvents.first { $0.id == eventID }
        XCTAssertNotNil(survivor, "Deleting a Deadline must not delete its logged Calendar Event")
        XCTAssertNil(survivor?.deadline)
    }

    func testUpcomingSortsByDueDateAndExcludesPast() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let past = try WorkItemService.createWorkItem(
            title: "Past Item", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let soon = try WorkItemService.createWorkItem(
            title: "Soon Item", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let later = try WorkItemService.createWorkItem(
            title: "Later Item", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        DeadlineService.setDeadline(for: past, label: "Past", dueAt: Date(timeIntervalSinceNow: -86400), context: context)
        DeadlineService.setDeadline(for: later, label: "Later", dueAt: Date(timeIntervalSinceNow: 86400 * 10), context: context)
        DeadlineService.setDeadline(for: soon, label: "Soon", dueAt: Date(timeIntervalSinceNow: 86400), context: context)
        try context.save()

        let upcoming = try DeadlineService.upcoming(in: context)
        XCTAssertEqual(upcoming.map(\.label), ["Soon", "Later"])
    }
}
