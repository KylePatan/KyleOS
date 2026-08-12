import SwiftUI
import SwiftData

/// PRD §4.4's Creative Capacity display. Fetches its own data via @Query rather than taking
/// props, matching Home's own principle (§4.1): "query shared underlying data rather than
/// maintain a separate duplicate task database."
struct CreativeCapacityWidget: View {
    @Query private var allSettings: [CreativeCapacityService.AppSettings]
    @Query private var allEvents: [CreativeCapacityService.CalendarEvent]
    @Query private var allPlannedSessions: [CreativeCapacityService.PlannedSession]

    private var summary: CreativeCapacityService.Summary? {
        guard let settings = allSettings.first else { return nil }
        return CreativeCapacityService.todaysCapacity(
            settings: settings, events: allEvents, plannedSessions: allPlannedSessions
        )
    }

    var body: some View {
        if let summary {
            HStack(spacing: 16) {
                capacityStat(label: "Available", hours: summary.baselineHours)
                capacityStat(label: "Scheduled", hours: summary.scheduledHours)
                capacityStat(label: "Remaining", hours: summary.remainingHours, emphasized: true)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.gray.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func capacityStat(label: String, hours: Double, emphasized: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(formatted(hours))
                .font(emphasized ? .headline : .body)
        }
    }

    private func formatted(_ hours: Double) -> String {
        hours.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(hours))h"
            : String(format: "%.1fh", hours)
    }
}
