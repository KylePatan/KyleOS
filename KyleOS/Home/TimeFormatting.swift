import Foundation

/// Small shared formatter so "45m" / "1h 5m" style duration text isn't reimplemented per view.
enum TimeFormatting {
    static func shortDuration(_ seconds: Int) -> String {
        let totalMinutes = max(seconds, 0) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 && minutes > 0 { return "\(hours)h \(minutes)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(minutes)m"
    }

    /// Kyle (2026-08-17): Weekly Board cards should read as "either 'no deadline' or a 'due in X
    /// amount of days'" at a glance, not a bare calendar date that needs mental math to place
    /// against today. Whole calendar days (not elapsed hours), so a deadline later today reads
    /// "Due today," not "Due in 0 days."
    static func dueLabel(for dueAt: Date?, now: Date = .now, calendar: Calendar = .current) -> String {
        guard let dueAt else { return "No deadline" }
        let startOfToday = calendar.startOfDay(for: now)
        let startOfDue = calendar.startOfDay(for: dueAt)
        let days = calendar.dateComponents([.day], from: startOfToday, to: startOfDue).day ?? 0
        switch days {
        case ..<0:
            let overdue = -days
            return "Overdue by \(overdue) day\(overdue == 1 ? "" : "s")"
        case 0: return "Due today"
        case 1: return "Due tomorrow"
        default: return "Due in \(days) days"
        }
    }
}
