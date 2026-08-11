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
}
