import Foundation
import SwiftData

/// Query/aggregation logic for the Home Today/Priority View (PRD §4.2), kept out of views per
/// CLAUDE.md §4. Deliberately simple — sort by hard-deadline proximity, then manual priority —
/// per the roadmap's own note that "intelligent scheduling can initially remain simpler" for
/// V0.1. The full multi-factor ranking in §4.2 (capacity, dependencies, remaining effort, ...)
/// is Scheduling Engine territory (V0.7, Decision Gate B), not decided here. Home "queries
/// shared underlying data rather than maintaining a separate duplicate task database" (§4.1) —
/// no new persisted model, just reads over WorkItem/Deadline/WorkSession.
enum HomeService {
    typealias WorkItem = KyleOSSchemaV9.WorkItem
    typealias Project = KyleOSSchemaV9.Project

    /// Active (not completed) Work Items, nearest hard deadline first (items with no deadline
    /// sort last), then higher manual priority first. A pure function over an already-fetched
    /// array — sorting by a relationship's date isn't reliably expressible as a single SwiftData
    /// #Predicate/SortDescriptor, and this keeps the ranking logic itself trivially testable.
    static func rankedTodayItems(from workItems: [WorkItem], limit: Int = 10) -> [WorkItem] {
        Array(
            workItems
                .filter { $0.status != .completed }
                .sorted { lhs, rhs in
                    switch (lhs.deadline?.dueAt, rhs.deadline?.dueAt) {
                    case let (l?, r?): return l < r
                    case (nil, nil): return lhs.priority > rhs.priority
                    case (nil, _): return false
                    case (_, nil): return true
                    }
                }
                .prefix(limit)
        )
    }

    /// PRD §5.6/§4.3: "cumulative logged project time" — summed from actual Work Sessions, not
    /// a separately-maintained total (§2.5: one source of truth).
    static func totalLoggedSeconds(for project: Project) -> Int {
        project.workItems.reduce(0) { total, workItem in
            total + workItem.workSessions.reduce(0) { $0 + $1.activeDurationSeconds }
        }
    }

    /// PRD's card example shows "Today's session: 45m" alongside the cumulative total — the
    /// active time logged today specifically, or nil if nothing was logged today yet.
    static func todaysSessionSeconds(for workItem: WorkItem, calendar: Calendar = .current, now: Date = .now) -> Int? {
        let todayStart = calendar.startOfDay(for: now)
        let todaysSessions = workItem.workSessions.filter { $0.startAt >= todayStart }
        guard !todaysSessions.isEmpty else { return nil }
        return todaysSessions.reduce(0) { $0 + $1.activeDurationSeconds }
    }

    /// All Tasks / Planning view (PRD §4.5): every unfinished Work Item, highest priority first
    /// — same "higher number = more important" convention as rankedTodayItems' tie-break, so the
    /// two views stay consistent with each other.
    static func allUnfinishedItems(from workItems: [WorkItem]) -> [WorkItem] {
        workItems
            .filter { $0.status != .completed }
            .sorted { $0.priority > $1.priority }
    }

    /// PRD §4.5: "Dragging changes priority, not just appearance." Renumbers priorities to match
    /// a manually-reordered list, preserving the "higher number = more important" convention —
    /// the top of the list (index 0) gets the highest value, so rankedTodayItems' existing
    /// descending sort stays correct without any change. A pure array transform matching
    /// SwiftUI's `List.onMove(perform:)` signature — the caller (a view's onMove handler) is
    /// responsible for actually persisting each pair via WorkItemService.setPriority.
    static func reorderedPriorities(
        current: [WorkItem],
        movingFromOffsets source: IndexSet,
        toOffset destination: Int
    ) -> [(item: WorkItem, newPriority: Int)] {
        var reordered = current
        reordered.move(fromOffsets: source, toOffset: destination)
        let count = reordered.count
        return reordered.enumerated().map { index, item in (item, count - 1 - index) }
    }
}
