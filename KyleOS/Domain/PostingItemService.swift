import Foundation
import SwiftData

/// Reusable domain actions for the Post It queue (PRD §10/§14.18), kept out of views per
/// CLAUDE.md §4. "Clips and Sketches should share a Posting Item model where practical" — a
/// PostingItem attaches to exactly one of Clip or a Sketch's Project, mirroring
/// `GigSetListService`'s "exactly one of joke/chunk" enforcement (the schema itself can't express
/// an exclusive-or, so the service layer does).
enum PostingItemService {
    typealias PostingItem = KyleOSSchemaV27.PostingItem
    typealias Clip = KyleOSSchemaV27.Clip
    typealias Project = KyleOSSchemaV27.Project

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
    static func setConfirmedPostDate(_ item: PostingItem, date: Date?, context: ModelContext) {
        item.confirmedPostDate = date
        item.updatedAt = .now
        if let clip = item.clip {
            ClipService.setPostDate(clip, date: date)
        }
        if let project = item.sketchProject {
            SketchProductionService.setPostDate(for: project, date: date, context: context)
        }
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
            ClipService.changeStatus(clip, to: .posted)
        }
        if let project = item.sketchProject {
            SketchProductionService.changeStatus(for: project, to: .posted, context: context)
        }
        item.actualPostedDate = now
        item.updatedAt = now
    }
}
