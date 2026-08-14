import Foundation

/// PRD §8.8/§10.4: "The user should be able to set a general goal such as 2–3 or 3 posts per
/// week. Kyle OS should suggest open posting dates and avoid unnecessary clustering when
/// possible... The posting calendar is shared across Clips and Sketches." Deliberately a pure,
/// deterministic function over already-stored confirmed post dates — no new persistence, no
/// randomness, explainable the same way Decision Gate B asks the eventual Scheduling Engine to be
/// (that gate itself remains unresolved and out of scope; this is a far narrower, self-contained
/// heuristic that doesn't touch any of its open questions).
enum PostingCadenceService {
    /// Suggests up to `target` open dates per week, for `weeksAhead` weeks starting from
    /// `startingFrom`, skipping any day that already has a confirmed post (the "avoid unnecessary
    /// clustering" instruction — spreads picks evenly across each week's remaining open days
    /// rather than bunching them at the start of the week).
    static func suggestedDates(
        target: Int,
        confirmedDates: [Date],
        startingFrom: Date = .now,
        weeksAhead: Int = 4,
        calendar: Calendar = .current
    ) -> [Date] {
        guard target > 0, weeksAhead > 0 else { return [] }

        var suggestions: [Date] = []
        var weekCursor = calendar.startOfDay(for: startingFrom)

        for _ in 0..<weeksAhead {
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: weekCursor) else { break }
            let confirmedThisWeek = confirmedDates.filter { weekInterval.contains($0) }
            let needed = max(target - confirmedThisWeek.count, 0)

            if needed > 0 {
                let usedDays = Set(confirmedThisWeek.map { calendar.startOfDay(for: $0) })
                var candidateDays: [Date] = []
                var day = max(calendar.startOfDay(for: startingFrom), weekInterval.start)
                while day < weekInterval.end {
                    if !usedDays.contains(day) { candidateDays.append(day) }
                    day = calendar.date(byAdding: .day, value: 1, to: day) ?? weekInterval.end
                }

                if !candidateDays.isEmpty {
                    let step = max(candidateDays.count / needed, 1)
                    var picked = 0
                    var index = 0
                    while picked < needed, index < candidateDays.count {
                        suggestions.append(candidateDays[index])
                        picked += 1
                        index += step
                    }
                }
            }

            guard let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: weekCursor) else { break }
            weekCursor = nextWeek
        }

        return suggestions
    }
}
