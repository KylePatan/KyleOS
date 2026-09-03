import Foundation
import SwiftData

/// Reusable domain actions for Submissions (festival/production-company submission deadlines),
/// kept out of views per CLAUDE.md §4.
///
/// Kyle (2026-08-27): "There needs to be another thing we can put in for 'HOME'... SUBMISSION.
/// And then it creates a home task. These are binary. So we need a way to complete them. We
/// should also add a section for submissions... festivals we need to submit for - have due
/// dates... and also have sections for (SUBMISSION COMING UP) and (SUBMISSION ENTERED). Also it's
/// a yearly thing, but the date may change. So if I submit to a festival it should remind me a
/// month before that the submissions may be coming up again."
///
/// A Submission carries up to two WorkItems over its life, distinguished by `workTypeName` (same
/// shape as Clip's Editing/Subtitling/Posting or Sketch's Writing/Editing/Posting): a "Submission"
/// task (this cycle's "prepare and send it in" work, the binary thing `markEntered` completes) and
/// a "Submission Reminder" task (created only once a due date is known, scheduled a month before
/// the same date next year — see `scheduleReopeningReminder`).
enum SubmissionService {
    typealias Submission = KyleOSSchemaV36.Submission
    typealias SubmissionStatus = KyleOSSchemaV36.SubmissionStatus
    typealias WorkItem = KyleOSSchemaV36.WorkItem

    private static let taskWorkTypeName = "Submission"
    private static let reminderWorkTypeName = "Submission Reminder"

    /// A festival's window is annual but the exact date "may change" year to year (Kyle's own
    /// words) — the only thing that can be projected with any confidence is "about the same time
    /// next year," so the reminder lands a month ahead of that, not on an assumed exact date.
    private static let reminderMonthsAfterDueDate = 11

    @discardableResult
    static func createSubmission(title: String, dueAt: Date? = nil, notes: String = "", context: ModelContext) -> Submission {
        let submission = Submission(title: title, notes: notes)
        context.insert(submission)
        _ = submissionTaskWorkItem(for: submission, context: context)
        if let dueAt {
            setDueDate(submission, to: dueAt, context: context)
        }
        return submission
    }

    /// Lazily finds or creates, same pattern as `WorkItemService.clipWorkItem`/`projectWritingWorkItem`.
    @discardableResult
    static func submissionTaskWorkItem(for submission: Submission, context: ModelContext) -> WorkItem {
        if let existing = submission.workItems.first(where: { $0.workTypeName == taskWorkTypeName }) {
            return existing
        }
        let workItem = WorkItem(title: submission.title, workspace: .submissions, workTypeName: taskWorkTypeName, project: nil)
        workItem.submission = submission
        context.insert(workItem)
        return workItem
    }

    private static func reminderWorkItem(for submission: Submission) -> WorkItem? {
        submission.workItems.first(where: { $0.workTypeName == reminderWorkTypeName })
    }

    /// The due date the "Coming Up" board card and Home task both read — kept in sync with the
    /// entry task's own Deadline (`DeadlineService`) rather than a second, independent date field,
    /// the same "one source of truth synced through the existing Deadline/Calendar pipeline" shape
    /// `PostingItemService` already established for Post Dates.
    static func setDueDate(_ submission: Submission, to date: Date, isHard: Bool = true, context: ModelContext) {
        submission.dueAt = date
        submission.updatedAt = .now
        let workItem = submissionTaskWorkItem(for: submission, context: context)
        DeadlineService.setDeadline(
            for: workItem,
            label: "\(submission.title) — Submission Due",
            dueAt: date,
            isHard: isHard,
            calendarEventType: .submissionDeadline,
            context: context
        )
    }

    static func removeDueDate(_ submission: Submission, context: ModelContext) {
        submission.dueAt = nil
        submission.updatedAt = .now
        if let workItem = submission.workItems.first(where: { $0.workTypeName == taskWorkTypeName }) {
            DeadlineService.removeDeadline(for: workItem, context: context)
        }
    }

    /// Kyle: "these are binary... we need a way to complete them." Completing marks the entry
    /// task done (so it drops off Home's To Do like any other completed Work Item) and — the
    /// "remind me a month before" ask — schedules next cycle's reopening nudge, only possible
    /// when a due date is actually known to project from.
    static func markEntered(_ submission: Submission, context: ModelContext) {
        submission.status = .entered
        submission.updatedAt = .now
        let task = submissionTaskWorkItem(for: submission, context: context)
        WorkItemService.complete(task, context: context)
        if let dueAt = submission.dueAt {
            scheduleReopeningReminder(for: submission, basedOn: dueAt, context: context)
        }
    }

    private static func scheduleReopeningReminder(for submission: Submission, basedOn dueAt: Date, context: ModelContext) {
        guard let reminderDate = Calendar.current.date(byAdding: .month, value: reminderMonthsAfterDueDate, to: dueAt) else { return }
        let workItem: WorkItem
        if let existing = reminderWorkItem(for: submission) {
            workItem = existing
        } else {
            workItem = WorkItem(
                title: "\(submission.title) — check if submissions reopened",
                workspace: .submissions,
                workTypeName: reminderWorkTypeName,
                project: nil
            )
            workItem.submission = submission
            context.insert(workItem)
        }
        DeadlineService.setDeadline(
            for: workItem,
            label: "\(submission.title) — may be open for submissions again",
            dueAt: reminderDate,
            isHard: false,
            calendarEventType: .submissionDeadline,
            context: context
        )
    }

    /// Kyle deliberately gets to act on this himself once he's confirmed the real new date
    /// (which "may change" year to year), rather than the app guessing one automatically —
    /// brings the Submission back to "Coming Up" so `setDueDate` is ready to be called again with
    /// whatever the confirmed date turns out to be. Also resets the entry task back to workable
    /// (not a fresh WorkItem — same reuse-in-place shape `DeadlineService.setDeadline` already
    /// uses for its own Deadline object) and completes the reminder, since acting on it is exactly
    /// what the reminder existed to prompt.
    static func reopenForNextCycle(_ submission: Submission, context: ModelContext) {
        submission.status = .comingUp
        submission.updatedAt = .now
        let task = submissionTaskWorkItem(for: submission, context: context)
        WorkItemService.changeStatus(task, to: .notStarted, context: context)
        task.progress = 0
        task.completedAt = nil
        task.updatedAt = .now
        if let reminder = reminderWorkItem(for: submission), reminder.status != .completed {
            WorkItemService.complete(reminder, context: context)
        }
    }

    /// `nil` when entered without ever setting a due date (nothing to project a reminder from) or
    /// before a Submission has ever been entered at all.
    static func reminderDate(for submission: Submission) -> Date? {
        reminderWorkItem(for: submission)?.deadline?.dueAt
    }

    static func rename(_ submission: Submission, to newTitle: String) {
        submission.title = newTitle
        submission.updatedAt = .now
        if let task = submission.workItems.first(where: { $0.workTypeName == taskWorkTypeName }) {
            WorkItemService.rename(task, to: newTitle)
        }
    }

    static func updateNotes(_ submission: Submission, to notes: String) {
        submission.notes = notes
        submission.updatedAt = .now
    }

    /// Deletes the Submission and its WorkItems together — Kyle never asked for a Submission to
    /// survive its own deletion the way, say, a Deadline's CalendarEvent does; `workItems` is
    /// nullify (not cascade) purely to match every other "WorkItem outlives its target"
    /// relationship in this schema, not because a dangling Submission WorkItem is meant to stick
    /// around after this call.
    static func delete(_ submission: Submission, context: ModelContext) {
        submission.workItems.forEach { context.delete($0) }
        context.delete(submission)
    }
}
