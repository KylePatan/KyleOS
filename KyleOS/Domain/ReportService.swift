import Foundation
import SwiftData

/// Reusable read-only aggregation for the Reports workspace (PRD §13), kept in its own service
/// boundary per CLAUDE.md §4's "Reporting boundary." §13.1: "Reports should be informative, not
/// punitive... should not create a single productivity score or enforce streaks" — every function
/// here returns plain counts/breakdowns, never a composite score.
///
/// §13.14: "Reports should require almost no separate data entry... calculate from Work Sessions,
/// Projects, status history, posting records, gigs, shoots, and Calendar capacity." This first
/// increment covers §13.2 (Default Summary) and the Workspace dimension of §13.4 (Time
/// Breakdowns) — everything computable from data that already exists. Deliberately deferred:
/// anything needing "status history"/"progress-over-time" (§13.5's progress history, §13.7's
/// estimate-accuracy-over-time, §13.9-§13.12's per-module reports, "Ready buffer trends") — no
/// Status/Progress History model exists anywhere in the schema yet (confirmed by search), so
/// those are a genuinely separate, larger increment, not a small addition to this one.
enum ReportService {
    typealias WorkSession = KyleOSSchemaV28.WorkSession
    typealias WorkItem = KyleOSSchemaV28.WorkItem
    typealias Workspace = KyleOSSchemaV28.Workspace
    typealias PostingItem = KyleOSSchemaV28.PostingItem

    enum DateRangeOption: String, CaseIterable, Identifiable {
        case thisWeek = "This Week"
        case lastWeek = "Last Week"
        case thisMonth = "This Month"
        case lastMonth = "Last Month"
        case custom = "Custom Range"
        var id: String { rawValue }
    }

    /// PRD §13.3: "This Week, Last Week, This Month, Last Month, Custom Range" — year/all-time
    /// explicitly deferred to "Future," not required for V0.9.
    static func interval(
        for option: DateRangeOption,
        customStart: Date = .now,
        customEnd: Date = .now,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> DateInterval {
        switch option {
        case .thisWeek:
            return calendar.dateInterval(of: .weekOfYear, for: now) ?? DateInterval(start: now, end: now)
        case .lastWeek:
            let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
            return calendar.dateInterval(of: .weekOfYear, for: lastWeek) ?? DateInterval(start: now, end: now)
        case .thisMonth:
            return calendar.dateInterval(of: .month, for: now) ?? DateInterval(start: now, end: now)
        case .lastMonth:
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return calendar.dateInterval(of: .month, for: lastMonth) ?? DateInterval(start: now, end: now)
        case .custom:
            let start = min(customStart, customEnd)
            let end = max(customStart, customEnd)
            return DateInterval(start: start, end: max(end, start))
        }
    }

    /// PRD §13.2: "Total Creative Time, Sessions, Projects Worked On, Completed Items, Content
    /// Posted." "Projects Worked On" counts distinct Projects only — Stand-Up material (Jokes/
    /// Chunks) and Clips have no Project relationship, so time spent there contributes to Total
    /// Creative Time and Sessions but not this specific count. An honest simplification, not a
    /// gap: PRD §13.4 already covers per-Workspace breakdowns separately (`workspaceBreakdown`
    /// below), which does include Stand-Up/Clips time.
    struct Summary: Equatable {
        let totalCreativeSeconds: Int
        let sessionCount: Int
        let projectsWorkedOnCount: Int
        let completedItemsCount: Int
        let contentPostedCount: Int
    }

    static func summary(in interval: DateInterval, context: ModelContext) throws -> Summary {
        let sessions = try workSessions(in: interval, context: context)
        let totalSeconds = sessions.reduce(0) { $0 + $1.activeDurationSeconds }
        let projectIDs = Set(sessions.compactMap { $0.workItem?.project?.id })

        // Filtered in-memory after a safe fetch, not via #Predicate — this codebase's established
        // workaround for Optional-Date nil-checks/enum comparisons not reliably evaluating in
        // SwiftData's #Predicate macro.
        let completedItemsCount = try context.fetch(FetchDescriptor<WorkItem>())
            .filter { item in
                guard let completedAt = item.completedAt else { return false }
                return interval.contains(completedAt)
            }
            .count

        let contentPostedCount = try context.fetch(FetchDescriptor<PostingItem>())
            .filter { item in
                guard let postedAt = item.actualPostedDate else { return false }
                return interval.contains(postedAt)
            }
            .count

        return Summary(
            totalCreativeSeconds: totalSeconds,
            sessionCount: sessions.count,
            projectsWorkedOnCount: projectIDs.count,
            completedItemsCount: completedItemsCount,
            contentPostedCount: contentPostedCount
        )
    }

    /// PRD §13.4: "Reports should support time by: Workspace..." Always returns all four
    /// Workspace cases (zero-filled), so the UI can render a stable, complete breakdown rather
    /// than a list that shrinks to nothing on a quiet week.
    static func workspaceBreakdown(in interval: DateInterval, context: ModelContext) throws -> [(workspace: Workspace, seconds: Int)] {
        let sessions = try workSessions(in: interval, context: context)
        var totals: [Workspace: Int] = [:]
        for session in sessions {
            guard let workspace = session.workItem?.workspace else { continue }
            totals[workspace, default: 0] += session.activeDurationSeconds
        }
        return Workspace.allCases.map { (workspace: $0, seconds: totals[$0] ?? 0) }
    }

    private static func workSessions(in interval: DateInterval, context: ModelContext) throws -> [WorkSession] {
        let start = interval.start
        let end = interval.end
        return try context.fetch(
            FetchDescriptor<WorkSession>(predicate: #Predicate { $0.startAt >= start && $0.startAt < end })
        )
    }
}
