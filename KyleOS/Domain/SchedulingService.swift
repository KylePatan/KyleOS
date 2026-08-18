import Foundation
import SwiftData

/// The Scheduling Engine's ranking core (PRD §4.2, Decision Gate B — `docs/PHASE_DECISION_REGISTER.md`).
/// Kept out of views per CLAUDE.md §4, as its own "Scheduling service boundary." Replaces
/// `HomeService.rankedTodayItems`'s deliberately-simple V0.1 deadline-then-priority sort with the
/// real multi-factor algorithm — that function stays in place as the documented V0.1-era
/// precedent, not deleted, until this actually replaces its call site in `HomeView`.
///
/// Decision Gate B was resolved by Kyle directly (2026-08-14), not invented here:
/// - Hard/soft deadline urgency dominates every other factor — "if something is due tomorrow,
///   that needs to be done."
/// - A "quick win" boost: something small enough to fully close in a session outweighs something
///   that would only add partial progress to a big pile, because finishing has real value.
/// - An anti-starvation/staleness boost, so "nothing gets lost in the cracks" and everything
///   eventually gets worked on — the longer an item sits untouched, the more its effective
///   priority rises.
/// - Manual priority and dependencies factor in beneath deadline urgency; a Work Item blocked by
///   an unfinished dependency isn't suggested at all (PRD §4.2 already lists "project dependencies"
///   as a required ranking input — this is the first real implementation of that requirement, not
///   new scope).
/// - Tie-breaking is NOT automatic: when the top two candidates score within a small margin of
///   each other, Kyle gets prompted to choose, and that choice becomes the tie-break (implemented
///   as a manual priority bump via the existing `WorkItemService.setPriority`, not a new schema
///   field — reuses the same "higher number = more important" mechanism the app already has).
///
/// Deliberately NOT built in this increment (increment 2's territory, PRD §4.6): cascade
/// rescheduling of already-planned sessions when Calendar capacity shrinks, and "prefer
/// concentrating a session's work around one or two projects" — that's a session-composition
/// concern for when Planned Sessions actually get built/reflowed, not this list-ranking pass.
enum SchedulingService {
    typealias WorkItem = KyleOSSchemaV31.WorkItem

    struct ScoredWorkItem: Identifiable {
        let workItem: WorkItem
        let score: Double
        var id: PersistentIdentifier { workItem.persistentModelID }
    }

    // Weights are scaled so a near-term deadline always dominates every other factor combined —
    // an item due within a few weeks outscores any combination of quick-win/staleness/priority
    // bonuses (which together top out well under 1,000), while a deadline far enough out
    // (~100+ days) decays to contributing nothing, so it doesn't artificially dominate forever.
    private static let deadlineBaseScore = 10_000.0
    private static let deadlineDecayPerDay = 100.0
    private static let quickWinBonus = 80.0
    private static let stalenessPerDay = 5.0
    private static let stalenessCap = 150.0
    private static let priorityWeight = 10.0

    /// Two items within this score margin of each other are "too close to call automatically" —
    /// candidates for the tie-break prompt rather than a silent pick. Comfortably smaller than a
    /// single manual-priority step (10 points), so a real, deliberate priority difference is never
    /// mistaken for a tie.
    static let tieMargin = 2.0

    /// PRD §4.4's own baseline example ("a normal available day/evening can generally support
    /// about 2-3 creative hours") — the default "can this be closed tonight?" threshold when the
    /// caller doesn't have today's actual remaining Creative Capacity on hand.
    static let defaultQuickWinThresholdMinutes = 120

    static func score(
        _ workItem: WorkItem,
        quickWinThresholdMinutes: Int = defaultQuickWinThresholdMinutes,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Double {
        var total = 0.0

        if let dueAt = workItem.deadline?.dueAt {
            let daysUntil = Double(calendar.dateComponents([.day], from: now, to: dueAt).day ?? 0)
            total += max(deadlineBaseScore - daysUntil * deadlineDecayPerDay, 0)
        }

        if workItem.estimatedRemainingMinutes > 0, workItem.estimatedRemainingMinutes <= quickWinThresholdMinutes {
            total += quickWinBonus
        }

        let lastActivity = workItem.workSessions.map(\.startAt).max() ?? workItem.createdAt
        let daysSinceActivity = Double(calendar.dateComponents([.day], from: lastActivity, to: now).day ?? 0)
        total += min(max(daysSinceActivity, 0) * stalenessPerDay, stalenessCap)

        total += Double(workItem.priority) * priorityWeight

        return total
    }

    /// PRD §4.2: "account for... project dependencies." A Work Item with any unfinished
    /// dependency isn't ready to suggest yet — excluded from the ranking rather than merely
    /// demoted, since it genuinely can't be started.
    static func isBlocked(_ workItem: WorkItem) -> Bool {
        workItem.dependsOn.contains { $0.status != .completed }
    }

    /// Active, unblocked Work Items ranked highest-score-first. A pure function over an
    /// already-fetched array, same shape as `HomeService.rankedTodayItems` — sorting on
    /// relationship-derived values isn't reliably expressible as a single SwiftData
    /// #Predicate/SortDescriptor, and this keeps the ranking itself trivially testable.
    static func rankedItems(
        from workItems: [WorkItem],
        quickWinThresholdMinutes: Int = defaultQuickWinThresholdMinutes,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [ScoredWorkItem] {
        workItems
            .filter { $0.status != .completed && !isBlocked($0) }
            .map { ScoredWorkItem(workItem: $0, score: score($0, quickWinThresholdMinutes: quickWinThresholdMinutes, now: now, calendar: calendar)) }
            .sorted { $0.score > $1.score }
    }

    /// If the #1 and #2 ranked items are within `tieMargin` of each other, they're a genuine tie
    /// at the top — the caller should prompt rather than silently show the sort order. Only the
    /// top spot matters here: a tie further down the list doesn't block a decision the way a tie
    /// for "what should I work on right now" does.
    static func topTie(in ranked: [ScoredWorkItem]) -> (first: ScoredWorkItem, second: ScoredWorkItem)? {
        guard ranked.count >= 2 else { return nil }
        let first = ranked[0]
        let second = ranked[1]
        guard abs(first.score - second.score) <= tieMargin else { return nil }
        return (first, second)
    }

    /// Records Kyle's tie-break choice as a manual priority bump — "the user gets to choose as
    /// the tie-breaker" (Decision Gate B). Reuses the existing priority mechanism rather than a
    /// new "pinned for today" field: a real choice about what matters more should persist beyond
    /// a single session, the same as any other manual priority change.
    static func resolveTie(choosing chosen: WorkItem, over other: WorkItem) {
        let boosted = min(max(chosen.priority, other.priority) + 1, 5)
        WorkItemService.setPriority(chosen, to: boosted)
    }
}
