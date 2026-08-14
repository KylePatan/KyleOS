import Foundation
import SwiftData

/// Reusable read-only aggregation for the Reports workspace (PRD §13), kept in its own service
/// boundary per CLAUDE.md §4's "Reporting boundary." §13.1: "Reports should be informative, not
/// punitive... should not create a single productivity score or enforce streaks" — every function
/// here returns plain counts/breakdowns, never a composite score.
///
/// §13.14: "Reports should require almost no separate data entry... calculate from Work Sessions,
/// Projects, status history, posting records, gigs, shoots, and Calendar capacity." Covers §13.2
/// (Default Summary), the Workspace dimension of §13.4, §13.6 (Planned vs Actual), §13.7
/// (Estimate Accuracy), and §13.8 (Active/Stalled Work) — everything computable from data that
/// already exists, no schema change. Deliberately still deferred: anything needing a genuine
/// point-in-time history (§13.5's progress-over-time, precise turnaround times, "Ready buffer
/// trends") — no Status/Progress History model exists anywhere in the schema yet (confirmed by
/// search), so those need a real new model, not just a new function here.
enum ReportService {
    typealias WorkSession = KyleOSSchemaV28.WorkSession
    typealias WorkItem = KyleOSSchemaV28.WorkItem
    typealias Workspace = KyleOSSchemaV28.Workspace
    typealias PostingItem = KyleOSSchemaV28.PostingItem
    typealias PlannedSession = KyleOSSchemaV28.PlannedSession
    typealias PlannedSessionStatus = KyleOSSchemaV28.PlannedSessionStatus

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

    /// PRD §13.6: "Reports should compare planned Creative Hours with actual Creative Hours and
    /// planned session length with actual session length." An aggregate comparison over the
    /// report's date range — not a 1:1 join of a specific Planned Session to the Work Session
    /// that fulfilled it, since no such link exists in the schema (both relate only through their
    /// shared WorkItem). Cancelled Planned Sessions are excluded (they were un-planned, not just
    /// unfulfilled); Missed ones still count as "planned" per PRD §11.10's own framing.
    struct PlannedVsActual: Equatable {
        let plannedHours: Double
        let actualHours: Double
        let plannedSessionCount: Int
        let actualSessionCount: Int
        var averagePlannedMinutes: Double { plannedSessionCount > 0 ? (plannedHours * 60) / Double(plannedSessionCount) : 0 }
        var averageActualMinutes: Double { actualSessionCount > 0 ? (actualHours * 60) / Double(actualSessionCount) : 0 }
    }

    static func plannedVsActual(in interval: DateInterval, context: ModelContext) throws -> PlannedVsActual {
        let start = interval.start
        let end = interval.end
        let planned = try context.fetch(
            FetchDescriptor<PlannedSession>(predicate: #Predicate { $0.scheduledAt >= start && $0.scheduledAt < end })
        ).filter { $0.status != .cancelled }
        let plannedMinutes = planned.reduce(0) { $0 + $1.plannedDurationMinutes }

        let actual = try workSessions(in: interval, context: context)
        let actualSeconds = actual.reduce(0) { $0 + $1.activeDurationSeconds }

        return PlannedVsActual(
            plannedHours: Double(plannedMinutes) / 60,
            actualHours: Double(actualSeconds) / 3600,
            plannedSessionCount: planned.count,
            actualSessionCount: actual.count
        )
    }

    /// PRD §13.7: "Kyle OS should compare default estimates with actual historical completion
    /// times. It may suggest updating a default, but must never silently change estimates without
    /// user approval." This returns the raw comparison data only — no auto-adjustment happens
    /// here or anywhere; any future "suggest updating a default" UI reads this and still requires
    /// an explicit user action to change a WorkTypeDefault.
    struct EstimateAccuracyEntry: Identifiable {
        let workItemID: PersistentIdentifier
        let title: String
        let workTypeName: String
        let estimatedMinutes: Int
        let actualMinutes: Int
        var id: PersistentIdentifier { workItemID }
        var varianceMinutes: Int { actualMinutes - estimatedMinutes }
    }

    static func estimateAccuracy(in interval: DateInterval, context: ModelContext) throws -> [EstimateAccuracyEntry] {
        try context.fetch(FetchDescriptor<WorkItem>())
            .compactMap { item -> EstimateAccuracyEntry? in
                guard let completedAt = item.completedAt, interval.contains(completedAt) else { return nil }
                let actualSeconds = item.workSessions.reduce(0) { $0 + $1.activeDurationSeconds }
                return EstimateAccuracyEntry(
                    workItemID: item.persistentModelID,
                    title: item.title,
                    workTypeName: item.workTypeName,
                    estimatedMinutes: item.estimatedTotalMinutes,
                    actualMinutes: actualSeconds / 60
                )
            }
    }

    /// PRD §13.8: "Reports can show active projects and optionally surface projects not worked on
    /// recently. This is informational and should not treat inactivity as failure." "Not worked
    /// on recently" is derived from the latest Work Session's start time (or creation time, if
    /// none exist yet) — not a stored flag, so it's always accurate as of the moment Reports is
    /// viewed rather than needing to be kept in sync.
    struct StalledWorkItemEntry: Identifiable {
        let workItemID: PersistentIdentifier
        let title: String
        let lastActivityAt: Date
        var id: PersistentIdentifier { workItemID }
    }

    static func stalledWorkItems(notWorkedOnSince cutoff: Date, context: ModelContext) throws -> [StalledWorkItemEntry] {
        try context.fetch(FetchDescriptor<WorkItem>())
            .filter { $0.status != .completed }
            .compactMap { item -> StalledWorkItemEntry? in
                let lastActivityAt = item.workSessions.map(\.startAt).max() ?? item.createdAt
                guard lastActivityAt < cutoff else { return nil }
                return StalledWorkItemEntry(workItemID: item.persistentModelID, title: item.title, lastActivityAt: lastActivityAt)
            }
            .sorted { $0.lastActivityAt < $1.lastActivityAt }
    }

    private static func workSessions(in interval: DateInterval, context: ModelContext) throws -> [WorkSession] {
        let start = interval.start
        let end = interval.end
        return try context.fetch(
            FetchDescriptor<WorkSession>(predicate: #Predicate { $0.startAt >= start && $0.startAt < end })
        )
    }
}
