import XCTest
import SwiftData
@testable import KyleOS

final class SubmissionServiceTests: XCTestCase {
    private typealias Submission = SubmissionService.Submission

    func testCreateSubmissionStartsComingUpWithATaskWorkItem() throws {
        let context = ModelContext(PersistenceController.makeInMemoryContainer())
        let submission = SubmissionService.createSubmission(title: "Just For Laughs", context: context)
        try context.save()

        XCTAssertEqual(submission.status, .comingUp)
        XCTAssertEqual(submission.workItems.count, 1)
        let task = try XCTUnwrap(submission.workItems.first)
        XCTAssertEqual(task.workTypeName, "Submission")
        XCTAssertEqual(task.workspace, .submissions)
        XCTAssertEqual(task.status, .notStarted)
    }

    func testSetDueDateSyncsACalendarEventOnTheTaskWorkItem() throws {
        let context = ModelContext(PersistenceController.makeInMemoryContainer())
        let submission = SubmissionService.createSubmission(title: "SNL", context: context)
        let dueDate = Date(timeIntervalSinceNow: 86400 * 10)
        SubmissionService.setDueDate(submission, to: dueDate, context: context)
        try context.save()

        XCTAssertEqual(submission.dueAt, dueDate)
        let task = try XCTUnwrap(submission.workItems.first { $0.workTypeName == "Submission" })
        let deadline = try XCTUnwrap(task.deadline)
        XCTAssertEqual(deadline.dueAt, dueDate)
        XCTAssertTrue(deadline.isHard)
        XCTAssertEqual(deadline.calendarEvents.first?.eventType, .submissionDeadline)
    }

    func testSettingDueDateTwiceUpdatesInPlaceRatherThanDuplicating() throws {
        let context = ModelContext(PersistenceController.makeInMemoryContainer())
        let submission = SubmissionService.createSubmission(title: "SNL", dueAt: Date(timeIntervalSinceNow: 86400), context: context)
        let secondDate = Date(timeIntervalSinceNow: 86400 * 20)
        SubmissionService.setDueDate(submission, to: secondDate, context: context)
        try context.save()

        XCTAssertEqual(submission.workItems.count, 1, "Editing the due date must not create a second Submission WorkItem")
        let task = try XCTUnwrap(submission.workItems.first)
        XCTAssertEqual(task.deadline?.calendarEvents.count, 1, "Must update the existing CalendarEvent, not create a duplicate")
        XCTAssertEqual(task.deadline?.dueAt, secondDate)
    }

    func testMarkEnteredCompletesTheTaskAndSchedulesAReopeningReminderElevenMonthsOut() throws {
        let context = ModelContext(PersistenceController.makeInMemoryContainer())
        let dueDate = Date(timeIntervalSinceNow: 86400 * 5)
        let submission = SubmissionService.createSubmission(title: "TIFF", dueAt: dueDate, context: context)

        SubmissionService.markEntered(submission, context: context)
        try context.save()

        XCTAssertEqual(submission.status, .entered)
        let task = try XCTUnwrap(submission.workItems.first { $0.workTypeName == "Submission" })
        XCTAssertEqual(task.status, .completed)
        XCTAssertNotNil(task.completedAt)

        let reminder = try XCTUnwrap(submission.workItems.first { $0.workTypeName == "Submission Reminder" })
        let reminderDeadline = try XCTUnwrap(reminder.deadline)
        let expected = try XCTUnwrap(Calendar.current.date(byAdding: .month, value: 11, to: dueDate))
        XCTAssertEqual(reminderDeadline.dueAt, expected, "Reminder should land a month before the same date next year")
        XCTAssertEqual(SubmissionService.reminderDate(for: submission), expected)
    }

    func testMarkEnteredWithoutADueDateSkipsSchedulingAReminder() throws {
        let context = ModelContext(PersistenceController.makeInMemoryContainer())
        let submission = SubmissionService.createSubmission(title: "No date yet", context: context)

        SubmissionService.markEntered(submission, context: context)
        try context.save()

        XCTAssertEqual(submission.status, .entered)
        XCTAssertNil(submission.workItems.first { $0.workTypeName == "Submission Reminder" })
        XCTAssertNil(SubmissionService.reminderDate(for: submission))
    }

    func testReopenForNextCycleResetsTheTaskAndCompletesTheReminder() throws {
        let context = ModelContext(PersistenceController.makeInMemoryContainer())
        let dueDate = Date(timeIntervalSinceNow: -86400 * 40)
        let submission = SubmissionService.createSubmission(title: "TIFF", dueAt: dueDate, context: context)
        SubmissionService.markEntered(submission, context: context)
        try context.save()

        SubmissionService.reopenForNextCycle(submission, context: context)
        try context.save()

        XCTAssertEqual(submission.status, .comingUp)
        let task = try XCTUnwrap(submission.workItems.first { $0.workTypeName == "Submission" })
        XCTAssertEqual(task.status, .notStarted, "Reopening must make the entry task actionable again for the new cycle")
        XCTAssertEqual(task.progress, 0)
        XCTAssertNil(task.completedAt)

        let reminder = try XCTUnwrap(submission.workItems.first { $0.workTypeName == "Submission Reminder" })
        XCTAssertEqual(reminder.status, .completed, "Acting on the reminder is exactly what it existed to prompt")
    }

    func testDeleteRemovesTheSubmissionAndItsWorkItems() throws {
        let context = ModelContext(PersistenceController.makeInMemoryContainer())
        let submission = SubmissionService.createSubmission(title: "Delete me", dueAt: Date(timeIntervalSinceNow: 86400), context: context)
        try context.save()

        SubmissionService.delete(submission, context: context)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<Submission>())
        XCTAssertTrue(remaining.isEmpty)
        let remainingWorkItems = try context.fetch(FetchDescriptor<WorkItemService.WorkItem>())
        XCTAssertTrue(remainingWorkItems.filter { $0.workTypeName == "Submission" }.isEmpty)
    }

    func testDeletingTheTaskWorkItemThroughUnderlyingContentDeletesTheWholeSubmission() throws {
        let context = ModelContext(PersistenceController.makeInMemoryContainer())
        let submission = SubmissionService.createSubmission(title: "Via Home right-click", context: context)
        try context.save()
        let task = try XCTUnwrap(submission.workItems.first)

        guard case .submission(let resolved) = WorkItemService.underlyingContent(for: task) else {
            XCTFail("Expected a Submission WorkItem to resolve to .submission")
            return
        }
        XCTAssertEqual(resolved.id, submission.id)

        WorkItemService.deleteUnderlyingContent(for: task, context: context)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<Submission>())
        XCTAssertTrue(remaining.isEmpty)
    }
}
