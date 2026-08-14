import SwiftUI
import SwiftData

/// PRD §13: the Reports workspace. Covers §13.2 (Default Summary, "This Week" by default),
/// §13.4's Workspace time breakdown, §13.6 (Planned vs Actual), §13.7 (Estimate Accuracy), §13.8
/// (Active/Stalled Work), and a first history-backed slice — Recent Activity, a chronological log
/// of status/progress changes (PRD §14.19) — see `ReportService`'s own doc comment for what's
/// still deliberately not built (a per-Project aggregate progress-over-time view; the ambiguity
/// is in how several Work Items' progress should combine, not a missing model).
struct ReportsView: View {
    @Environment(\.modelContext) private var context

    @State private var rangeOption: ReportService.DateRangeOption = .thisWeek
    @State private var customStart = Date.now
    @State private var customEnd = Date.now
    @State private var summary: ReportService.Summary?
    @State private var breakdown: [(workspace: ReportService.Workspace, seconds: Int)] = []
    @State private var plannedVsActual: ReportService.PlannedVsActual?
    @State private var estimateAccuracy: [ReportService.EstimateAccuracyEntry] = []
    @State private var stalledWorkItems: [ReportService.StalledWorkItemEntry] = []
    @State private var recentActivity: [ReportService.HistoryEntry] = []

    private var interval: DateInterval {
        ReportService.interval(for: rangeOption, customStart: customStart, customEnd: customEnd)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                rangePicker
                if let summary {
                    summaryGrid(summary)
                }
                if !breakdown.isEmpty {
                    workspaceBreakdownSection
                }
                if let plannedVsActual {
                    plannedVsActualSection(plannedVsActual)
                }
                if !estimateAccuracy.isEmpty {
                    estimateAccuracySection
                }
                if !stalledWorkItems.isEmpty {
                    stalledWorkSection
                }
                if !recentActivity.isEmpty {
                    recentActivitySection
                }
            }
            .padding()
        }
        .navigationTitle("Reports")
        .onAppear(perform: reload)
        .onChange(of: rangeOption) { reload() }
        .onChange(of: customStart) { if rangeOption == .custom { reload() } }
        .onChange(of: customEnd) { if rangeOption == .custom { reload() } }
    }

    private var rangePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Date range", selection: $rangeOption) {
                ForEach(ReportService.DateRangeOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 500)

            if rangeOption == .custom {
                HStack {
                    DatePicker("From", selection: $customStart, displayedComponents: .date)
                    DatePicker("To", selection: $customEnd, displayedComponents: .date)
                }
            }
        }
    }

    /// PRD §13.2: "Total Creative Time, Sessions, Projects Worked On, Completed Items, Content
    /// Posted."
    private func summaryGrid(_ summary: ReportService.Summary) -> some View {
        HStack(alignment: .top, spacing: 24) {
            stat(label: "Total Creative Time", value: TimeFormatting.shortDuration(summary.totalCreativeSeconds))
            stat(label: "Sessions", value: "\(summary.sessionCount)")
            stat(label: "Projects Worked On", value: "\(summary.projectsWorkedOnCount)")
            stat(label: "Completed Items", value: "\(summary.completedItemsCount)")
            stat(label: "Content Posted", value: "\(summary.contentPostedCount)")
        }
    }

    private func stat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.bold())
        }
    }

    /// PRD §13.4: "Reports should support time by: Workspace..."
    private var workspaceBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Time by Workspace").font(.headline)
            ForEach(breakdown, id: \.workspace) { entry in
                HStack {
                    Text(entry.workspace.rawValue)
                    Spacer()
                    Text(TimeFormatting.shortDuration(entry.seconds))
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
            }
        }
        .frame(maxWidth: 400, alignment: .leading)
    }

    /// PRD §13.6: "Compare planned Creative Hours with actual Creative Hours and planned session
    /// length with actual session length."
    private func plannedVsActualSection(_ comparison: ReportService.PlannedVsActual) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Planned vs Actual").font(.headline)
            HStack(spacing: 24) {
                stat(label: "Planned Hours", value: TimeFormatting.shortDuration(Int(comparison.plannedHours * 3600)))
                stat(label: "Actual Hours", value: TimeFormatting.shortDuration(Int(comparison.actualHours * 3600)))
                stat(label: "Avg Planned Session", value: TimeFormatting.shortDuration(Int(comparison.averagePlannedMinutes * 60)))
                stat(label: "Avg Actual Session", value: TimeFormatting.shortDuration(Int(comparison.averageActualMinutes * 60)))
            }
        }
    }

    /// PRD §13.7: "Compare default estimates with actual historical completion times." Read-only
    /// display — no button here changes any estimate, matching the PRD's "must never silently
    /// change estimates without user approval."
    private var estimateAccuracySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Estimate Accuracy — Completed This Range").font(.headline)
            ForEach(estimateAccuracy) { entry in
                HStack {
                    Text(entry.title)
                    Text("(\(entry.workTypeName))").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("Est \(entry.estimatedMinutes)m")
                        .foregroundStyle(.secondary)
                    Text("Actual \(entry.actualMinutes)m")
                        .foregroundStyle(.secondary)
                    Text(entry.varianceMinutes >= 0 ? "+\(entry.varianceMinutes)m" : "\(entry.varianceMinutes)m")
                        .foregroundStyle(entry.varianceMinutes > 0 ? .orange : .green)
                }
                .font(.callout)
            }
        }
        .frame(maxWidth: 700, alignment: .leading)
    }

    /// PRD §13.8: "Optionally surface projects not worked on recently. This is informational and
    /// should not treat inactivity as failure" — plain list, no visual alarm styling.
    private var stalledWorkSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Not Worked On Recently (14+ days)").font(.headline)
            ForEach(stalledWorkItems) { entry in
                HStack {
                    Text(entry.title)
                    Spacer()
                    Text(entry.lastActivityAt, format: .dateTime.month().day().year())
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
            }
        }
        .frame(maxWidth: 500, alignment: .leading)
    }

    /// PRD §14.19: "Important status changes and progress changes should create history records."
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Activity").font(.headline)
            ForEach(recentActivity) { entry in
                HStack {
                    Text(entry.subjectTitle)
                    Text(entry.kind.rawValue).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(entry.oldValue) → \(entry.newValue)")
                        .foregroundStyle(.secondary)
                    Text(entry.occurredAt, format: .dateTime.month().day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
            }
        }
        .frame(maxWidth: 700, alignment: .leading)
    }

    private func reload() {
        let currentInterval = interval
        summary = try? ReportService.summary(in: currentInterval, context: context)
        breakdown = (try? ReportService.workspaceBreakdown(in: currentInterval, context: context)) ?? []
        plannedVsActual = try? ReportService.plannedVsActual(in: currentInterval, context: context)
        estimateAccuracy = (try? ReportService.estimateAccuracy(in: currentInterval, context: context)) ?? []
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
        stalledWorkItems = (try? ReportService.stalledWorkItems(notWorkedOnSince: cutoff, context: context)) ?? []
        recentActivity = (try? ReportService.recentActivity(in: currentInterval, context: context)) ?? []
    }
}

#Preview {
    NavigationStack {
        ReportsView()
    }
    .modelContainer(PersistenceController.makeInMemoryContainer())
}
