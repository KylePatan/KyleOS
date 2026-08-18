import Foundation
import SwiftData

/// Reusable domain actions for the Post It queue (PRD §10/§14.18), kept out of views per
/// CLAUDE.md §4. "Clips and Sketches should share a Posting Item model where practical" — a
/// PostingItem attaches to exactly one of Clip or a Sketch's Project, mirroring
/// `GigSetListService`'s "exactly one of joke/chunk" enforcement (the schema itself can't express
/// an exclusive-or, so the service layer does).
enum PostingItemService {
    typealias PostingItem = KyleOSSchemaV31.PostingItem
    typealias Clip = KyleOSSchemaV31.Clip
    typealias Project = KyleOSSchemaV31.Project
    typealias WorkItem = KyleOSSchemaV31.WorkItem

    /// PRD §10.2's five display states. Deliberately not a stored field — computed fresh from the
    /// content's own ready/posted state (already fully answered by `ClipStatus`/
    /// `SketchProductionStatus`) plus `confirmedPostDate`, avoiding a second source of truth that
    /// could drift from the content's real status.
    enum DisplayStatus: String, CaseIterable {
        case notReady = "Not Ready"
        case ready = "Ready"
        case dueToday = "Due Today"
        case posted = "Posted"
        case overdue = "Overdue"
    }

    static func displayStatus(
        isReady: Bool,
        isPosted: Bool,
        confirmedPostDate: Date?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> DisplayStatus {
        if isPosted { return .posted }
        if !isReady { return .notReady }
        guard let confirmedPostDate else { return .ready }
        if calendar.isDate(confirmedPostDate, inSameDayAs: now) { return .dueToday }
        if confirmedPostDate < now { return .overdue }
        return .ready
    }

    static func displayStatus(for clip: Clip, now: Date = .now, calendar: Calendar = .current) -> DisplayStatus {
        displayStatus(
            isReady: ClipService.boardLane(for: clip.status) == .ready,
            isPosted: clip.status == .posted,
            confirmedPostDate: clip.postingItem?.confirmedPostDate,
            now: now,
            calendar: calendar
        )
    }

    static func displayStatus(for project: Project, now: Date = .now, calendar: Calendar = .current) -> DisplayStatus {
        let status = SketchProductionService.status(for: project)
        return displayStatus(
            isReady: status == .ready,
            isPosted: status == .posted,
            confirmedPostDate: project.postingItem?.confirmedPostDate,
            now: now,
            calendar: calendar
        )
    }

    @discardableResult
    static func findOrCreate(for clip: Clip, context: ModelContext) -> PostingItem {
        if let existing = clip.postingItem { return existing }
        let item = PostingItem(clip: clip)
        context.insert(item)
        clip.postingItem = item
        return item
    }

    @discardableResult
    static func findOrCreate(for project: Project, context: ModelContext) -> PostingItem {
        if let existing = project.postingItem { return existing }
        let item = PostingItem(sketchProject: project)
        context.insert(item)
        project.postingItem = item
        return item
    }

    static func setSuggestedPostDate(_ item: PostingItem, date: Date?) {
        item.suggestedPostDate = date
        item.updatedAt = .now
    }

    /// PRD §8.8: "Suggested Post Dates can move; confirmed Post Dates become hard deadlines until
    /// manually changed." Also keeps `Clip.postDate`/the Sketch's `SketchProduction.postDate` in
    /// sync so the pre-existing Ready Queue UI (built before Post It existed) keeps working
    /// unchanged — same "sync a linked field" shape as `GigService`'s CalendarEvent sync.
    ///
    /// Kyle (2026-08-17): confirmed post dates should "show up in my calendar - as well as my to
    /// do" and are "static and do not change from the day they're supposed to be posted." Routed
    /// through the same Deadline/CalendarEvent pipeline as every other deadline (via a dedicated
    /// "Clip Posting"/"Sketch Posting" WorkItem, so `SchedulingService` ranks it into the Weekly
    /// Board same as any other deadline) — tagged `.postDate` rather than `.hardDeadline` for the
    /// right label on Calendar, and its CalendarEvent is locked immediately (not just on
    /// `DeadlineService.confirm`) since a *confirmed* post date is deliberately more rigid than an
    /// ordinary deadline from the moment it's set, matching "static... do not change."
    static func setConfirmedPostDate(_ item: PostingItem, date: Date?, context: ModelContext) {
        item.confirmedPostDate = date
        item.updatedAt = .now
        if let clip = item.clip {
            ClipService.setPostDate(clip, date: date)
            syncPostDateDeadline(date: date, label: "Post: \(clip.title)", workItem: try? WorkItemService.clipPostingWorkItem(for: clip, context: context), context: context)
        }
        if let project = item.sketchProject {
            SketchProductionService.setPostDate(for: project, date: date, context: context)
            syncPostDateDeadline(date: date, label: "Post: \(project.title)", workItem: try? WorkItemService.sketchPostingWorkItem(for: project, context: context), context: context)
        }
    }

    private static func syncPostDateDeadline(date: Date?, label: String, workItem: WorkItem?, context: ModelContext) {
        guard let workItem else { return }
        guard let date else {
            DeadlineService.removeDeadline(for: workItem, context: context)
            return
        }
        let deadline = DeadlineService.setDeadline(
            for: workItem, label: label, dueAt: date, isHard: true, calendarEventType: .postDate, context: context
        )
        if let event = deadline.calendarEvents.first {
            CalendarEventService.setLocked(event, true)
        }
    }

    /// PRD §10.4's "shared across Clips and Sketches" confirmed-date pool, pulled out of
    /// `PostItView` so any other screen suggesting a date (e.g. a single Clip's own detail view)
    /// avoids the same already-used days rather than re-deriving a narrower, possibly-colliding
    /// pool of its own.
    static func allConfirmedPostDates(in context: ModelContext) -> [Date] {
        let clips = (try? context.fetch(FetchDescriptor<Clip>())) ?? []
        let projects = (try? context.fetch(FetchDescriptor<Project>())) ?? []
        let clipDates = clips.compactMap { clip -> Date? in
            guard displayStatus(for: clip) != .posted else { return nil }
            return clip.postingItem?.confirmedPostDate
        }
        let sketchDates = projects
            .filter { $0.projectType == .sketch && $0.status == .finished && !$0.isArchived }
            .compactMap { project -> Date? in
                guard displayStatus(for: project) != .posted else { return nil }
                return project.postingItem?.confirmedPostDate
            }
        return clipDates + sketchDates
    }

    /// Kyle (2026-08-17): "when something is finished you put in a manual post date and depending
    /// on the settings for when we should post - it slots it into there." One concrete next slot
    /// (the weekly posting-goal Stepper already in `PostItView` is "the settings"; `nil` if no
    /// goal is set, so callers can hide the suggestion entirely rather than show a meaningless one).
    static func recommendedPostDate(in context: ModelContext) -> Date? {
        guard let settings = try? SettingsService.currentSettings(in: context), settings.displayPostsPerWeekTarget > 0 else { return nil }
        let confirmed = allConfirmedPostDates(in: context)
        return PostingCadenceService.suggestedDates(target: settings.displayPostsPerWeekTarget, confirmedDates: confirmed).first
    }

    static func setPlatform(_ item: PostingItem, platform: String) {
        item.platform = platform
        item.updatedAt = .now
    }

    /// PRD §8.9: "The user marks it Posted after publishing. Kyle OS records actual post date and
    /// completion history." Advances the underlying content's own status to Posted (the real
    /// source of truth `displayStatus` reads) and records the distinct actual-posted timestamp.
    static func markPosted(_ item: PostingItem, context: ModelContext, now: Date = .now) {
        if let clip = item.clip {
            ClipService.changeStatus(clip, to: .posted, context: context)
        }
        if let project = item.sketchProject {
            SketchProductionService.changeStatus(for: project, to: .posted, context: context)
        }
        item.actualPostedDate = now
        item.updatedAt = now
    }
}
